#!/usr/bin/env python3
# Adapted from Omarchy's omarchy-agent-usage-codex.
# Source: https://github.com/basecamp/omarchy
# SPDX-License-Identifier: MIT
#
# Copyright (c) David Heinemeier Hansson
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
"""Collect Codex usage into one display-ready JSON record.

Local stats come from native Codex CLI session files, pi/omp sessions that
ran through openai-codex, and opencode sessions that ran on an OpenAI
provider; rate limits and the plan come from the Codex app-server RPC. The Quickshell
panel only ever reads the JSON this prints.
"""

import argparse
import fcntl
import hashlib
import json
import os
import select
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

AGENT_ID = "codex"
AGENT_NAME = "Codex"
AUTH_HELP = "Run `codex login` to authenticate."

# Briefly reuse local scans across concurrent widget refreshes.
# --limits-only always probes fresh limits, but may reuse local stats for
# up to 15 minutes. --force bypasses the local cache.
SCAN_REUSE_SECONDS = 20
LIMITS_ONLY_REUSE_SECONDS = 900


def local_day(value):
    if value is None:
        return datetime.now().strftime("%Y-%m-%d")
    if isinstance(value, (int, float)):
        # pi message timestamps are milliseconds; Codex timestamps are usually seconds.
        if value > 10_000_000_000:
            value = value / 1000
        return datetime.fromtimestamp(value).strftime("%Y-%m-%d")
    text = str(value)
    try:
        if text.endswith("Z"):
            dt = datetime.fromisoformat(text[:-1] + "+00:00")
        else:
            dt = datetime.fromisoformat(text)
        if dt.tzinfo is not None:
            dt = dt.astimezone()
        return dt.strftime("%Y-%m-%d")
    except Exception:
        return datetime.now().strftime("%Y-%m-%d")


def number(value):
    try:
        return int(value or 0)
    except Exception:
        return 0


def model_name(raw):
    value = str(raw or "codex")
    return value if value else "codex"


def runtime_env():
    home = str(Path.home())
    path_parts = [
        os.environ.get("PATH", ""),
        f"{home}/.local/bin",
        f"{home}/.npm-global/bin",
        f"{home}/.local/share/mise/shims",
    ]
    env = os.environ.copy()
    env["PATH"] = os.pathsep.join(part for part in path_parts if part)
    return env


ENV = runtime_env()


def find_command(name):
    return shutil.which(name, path=ENV.get("PATH"))


now = datetime.now()
today = now.strftime("%Y-%m-%d")
recent_dates = [(now - timedelta(days=offset)).strftime("%Y-%m-%d") for offset in range(6, -1, -1)]
recent = {day: {"date": day, "messageCount": 0} for day in recent_dates}
today_tokens_by_model = {}
model_usage = {}
today_sessions = set()
active_days = set()

today_prompts = 0
today_total_tokens = 0
total_prompts = 0
total_sessions = set()
seen_pi_messages = set()


def add_usage(day, session_key, model, input_tokens, output_tokens, cache_read, cache_write):
    global today_prompts, today_total_tokens, total_prompts
    total = input_tokens + output_tokens + cache_read + cache_write
    total_prompts += 1
    total_sessions.add(session_key)
    active_days.add(day)

    bucket = model_usage.setdefault(model, {
        "inputTokens": 0,
        "outputTokens": 0,
        "cacheReadInputTokens": 0,
        "cacheCreationInputTokens": 0,
    })
    bucket["inputTokens"] += input_tokens
    bucket["outputTokens"] += output_tokens
    bucket["cacheReadInputTokens"] += cache_read
    bucket["cacheCreationInputTokens"] += cache_write

    if day in recent:
        recent[day]["messageCount"] += total

    if day == today:
        today_prompts += 1
        today_sessions.add(session_key)
        today_total_tokens += total
        today_tokens_by_model[model] = today_tokens_by_model.get(model, 0) + total


def scan_pi_sessions():
    roots = [
        Path.home() / ".pi" / "agent" / "sessions",
        Path.home() / ".omp" / "agent" / "sessions",
    ]
    rg = find_command("rg") or "rg"
    complete = True
    for root in roots:
        if not root.exists():
            continue
        try:
            proc = subprocess.Popen(
                [rg, "--json", "-e", r'"provider"\s*:\s*"openai-codex"', "-e", r'"api"\s*:\s*"openai-codex', str(root)],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                errors="replace",
                env=ENV,
            )
        except OSError as exc:
            print(f"CodexUsage: could not scan pi/OMP sessions ({exc})", file=sys.stderr)
            return False

        assert proc.stdout is not None
        for raw in proc.stdout:
            try:
                event = json.loads(raw)
                if event.get("type") != "match":
                    continue
                line = event.get("data", {}).get("lines", {}).get("text", "")
                path = event.get("data", {}).get("path", {}).get("text", "pi-session")
                entry = json.loads(line)
            except Exception:
                continue

            if not isinstance(entry, dict) or entry.get("type") != "message":
                continue
            message_key = path + ":" + str(entry.get("id") or event.get("data", {}).get("line_number"))
            if message_key in seen_pi_messages:
                continue
            seen_pi_messages.add(message_key)
            message = entry.get("message") or {}
            if not isinstance(message, dict) or message.get("role") != "assistant":
                continue
            provider = str(message.get("provider") or "")
            api = str(message.get("api") or "")
            if provider != "openai-codex" and not api.startswith("openai-codex"):
                continue

            usage = message.get("usage") or {}
            if not isinstance(usage, dict) or not usage:
                continue
            total = number(usage.get("totalTokens"))
            input_tokens = number(usage.get("input"))
            output_tokens = number(usage.get("output"))
            cache_read = number(usage.get("cacheRead"))
            cache_write = number(usage.get("cacheWrite"))
            if total and not (input_tokens or output_tokens or cache_read or cache_write):
                input_tokens = total
            if not (input_tokens or output_tokens or cache_read or cache_write):
                continue

            day = local_day(entry.get("timestamp") or message.get("timestamp"))
            session_key = path
            add_usage(day, session_key, model_name(message.get("model")), input_tokens, output_tokens, cache_read, cache_write)

        try:
            if proc.wait(timeout=1) not in (0, 1):
                complete = False
                print(f"CodexUsage: pi/OMP scan failed for {root}", file=sys.stderr)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
            complete = False
        finally:
            proc.stdout.close()
    return complete


def scan_opencode_sessions():
    # A subscription burned entirely through opencode leaves no native session
    # files, but opencode records per-message provider, model, and token usage
    # in its own database. Read-only: opencode may be writing right now.
    # Returns whether the scan ran to completion: a scan cut short by a
    # database error still contributes what it read, but must not be cached
    # as if it were the whole story.
    db = Path(os.environ.get("XDG_DATA_HOME") or (Path.home() / ".local" / "share")) / "opencode" / "opencode.db"
    if not db.is_file():
        return True
    try:
        conn = sqlite3.connect(db.resolve().as_uri() + "?mode=ro", uri=True, timeout=2)
    except sqlite3.Error:
        return False
    try:
        conn.execute("PRAGMA query_only = ON")
        # OpenCode DBs grow huge (every historical message, JSON included), and
        # Python-side json.loads of every row wasted ~600 MB of RSS on machines
        # whose subscription never ran on OpenAI. The json_extract conditions are
        # the authority for the rows that reach them: role == "assistant" and
        # providerID == "openai", the same exact-match values the Python filter
        # below checks. The guards in front are pure acceleration, not a perfect
        # proxy for the Python filter:
        #   - The LIKE gates skip rows whose JSON cannot contain the two
        #     key/value pairs, avoiding the JSON parse of tens-of-MB blobs. They
        #     can differ from json.loads on duplicate keys (Python keeps the
        #     last, SQLite json_extract keeps the first) and ASCII-escaped
        #     values (\"ass\\u0069stant\" decodes for Python but not for LIKE),
        #     so a row the authority would accept can be gated out. Both cases
        #     are vanishingly rare in real opencode data.
        #   - json_valid guards the parse itself: json_extract() RAISES on
        #     malformed JSON instead of returning NULL, and one such row would
        #     otherwise abort the whole scan. SQLite does not promise that AND
        #     terms evaluate left to right, so the guard is a CASE around each
        #     json_extract rather than a separate AND term. Rows that are not
        #     well-formed JSON are skipped here; the per-row try/except below
        #     stays as the final safety net for rows that pass the SQL filter
        #     but fail json.loads.
        for session_id, raw in conn.execute(
            "SELECT session_id, data FROM message"
            " WHERE data LIKE '%\"role\"%:%\"assistant\"%'"
            " AND data LIKE '%\"providerID\"%:%\"openai\"%'"
            " AND CASE WHEN json_valid(data) THEN json_extract(data, '$.role') END = 'assistant'"
            " AND CASE WHEN json_valid(data) THEN json_extract(data, '$.providerID') END = 'openai'"
        ):
            # One malformed row must not abort the scan, so every shape assumption
            # lives inside the try.
            try:
                entry = json.loads(raw)
                # Exact match: opencode provider ids are free-form, and a custom
                # "openai-local" gateway is not this subscription.
                if not isinstance(entry, dict) or entry.get("role") != "assistant":
                    continue
                if str(entry.get("providerID") or "") != "openai":
                    continue
                tokens = entry.get("tokens") or {}
                cache = tokens.get("cache") or {}
                input_tokens = number(tokens.get("input"))
                # opencode keeps thinking tokens out of output; both are generated.
                output_tokens = number(tokens.get("output")) + number(tokens.get("reasoning"))
                cache_read = number(cache.get("read"))
                cache_write = number(cache.get("write"))
                if not (input_tokens or output_tokens or cache_read or cache_write):
                    continue
                day = local_day((entry.get("time") or {}).get("created"))
                model = model_name(str(entry.get("modelID") or "").rstrip("/").split("/")[-1])
            except Exception:
                continue
            add_usage(day, "opencode:" + str(session_id), model, input_tokens, output_tokens, cache_read, cache_write)
    except sqlite3.Error:
        # Transient lock, schema migration, corruption: the numbers stop here,
        # incomplete.
        return False
    finally:
        conn.close()
    return True


def scan_native_codex_sessions():
    codex_home = Path(os.environ.get("CODEX_HOME") or (Path.home() / ".codex"))
    roots = [codex_home / "sessions", codex_home / "archived_sessions"]
    cutoff = time.time() - 30 * 24 * 60 * 60
    complete = True
    for root in roots:
        if not root.exists():
            continue
        for path in root.rglob("*.jsonl"):
            current_model = "codex"
            previous_total = None
            try:
                modified = path.stat().st_mtime
                if modified < cutoff:
                    continue
                with path.open(errors="replace") as handle:
                    for raw in handle:
                        try:
                            entry = json.loads(raw)
                        except (ValueError, TypeError):
                            continue
                        if not isinstance(entry, dict):
                            continue
                        payload = entry.get("payload") or entry
                        if not isinstance(payload, dict):
                            continue
                        if entry.get("type") == "turn_context":
                            current_model = model_name(payload.get("model") or payload.get("model_slug") or current_model)
                            continue
                        if entry.get("type") == "response_item":
                            payload = payload.get("payload") or payload
                        if not isinstance(payload, dict) or payload.get("type") != "token_count":
                            continue
                        info = payload.get("info")
                        if not isinstance(info, dict):
                            continue
                        cumulative = info.get("total_token_usage")
                        if isinstance(cumulative, dict):
                            snapshot = tuple(number(cumulative.get(key)) for key in (
                                "input_tokens", "cached_input_tokens", "cache_write_input_tokens",
                                "output_tokens", "reasoning_output_tokens", "total_tokens",
                            ))
                            # Codex re-emits TokenCountEvent for rate-limit updates with
                            # unchanged TokenUsageInfo. last_token_usage is still the prior
                            # response in those events, not new usage. Gate on cumulative
                            # counters, but add only the last response, never the total.
                            if snapshot == previous_total:
                                continue
                            previous_total = snapshot
                        usage = info.get("last_token_usage")
                        if not isinstance(usage, dict):
                            continue
                        cache_read = max(0, number(usage.get("cached_input_tokens")))
                        cache_write = max(0, number(usage.get("cache_write_input_tokens")))
                        # Cached input and reasoning output are already included in the
                        # respective input/output counters. Keep four exclusive buckets.
                        input_tokens = max(0, number(usage.get("input_tokens")) - cache_read - cache_write)
                        output_tokens = max(0, number(usage.get("output_tokens")))
                        if not (input_tokens or output_tokens or cache_read or cache_write):
                            continue
                        day = local_day(entry.get("timestamp") or modified)
                        add_usage(day, str(path), current_model, input_tokens, output_tokens, cache_read, cache_write)
            except OSError as exc:
                print(f"CodexUsage: could not read native session {path} ({exc})", file=sys.stderr)
                complete = False
    return complete


def cache_root():
    root = Path(os.environ.get("XDG_CACHE_HOME") or (Path.home() / ".cache")) / "quickshell" / "codex-usage"
    root.mkdir(parents=True, exist_ok=True)
    return root


def scan_cache_paths():
    codex_home = Path(os.environ.get("CODEX_HOME") or (Path.home() / ".codex"))
    db = Path(os.environ.get("XDG_DATA_HOME") or (Path.home() / ".local" / "share")) / "opencode" / "opencode.db"
    # The digest covers every data path the scan reads: the codex session
    # roots, the opencode DB, and (via Path.home()) the pi/omp session roots.
    digest = hashlib.sha1((str(Path.home()) + "\n" + str(codex_home) + "\n" + str(db)).encode("utf-8")).hexdigest()[:16]
    root = cache_root()
    return root / f"codex-scan-{digest}.json", root / f"codex-scan-{digest}.lock"


def read_fresh_json(path, max_age_seconds):
    if max_age_seconds <= 0 or not path.exists():
        return None
    try:
        # A negative age means the mtime is in the future: the clock moved
        # backwards since the write, so the cache's freshness cannot be trusted.
        age = time.time() - path.stat().st_mtime
        if 0 <= age <= max_age_seconds:
            return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None
    return None


def write_json(path, payload):
    # A unique temporary file and atomic rename keep concurrent readers from
    # seeing a partially written cache.
    handle_fd, tmp_name = tempfile.mkstemp(dir=path.parent, prefix=path.name + ".", suffix=".tmp")
    tmp = Path(tmp_name)
    try:
        with os.fdopen(handle_fd, "w", encoding="utf-8") as handle:
            handle.write(json.dumps(payload, separators=(",", ":")) + "\n")
        # mkstemp opens at 0600; nothing in the cache is sensitive, so open it
        # up to the usual 0644.
        tmp.chmod(0o644)
        tmp.replace(path)
    except BaseException:
        tmp.unlink(missing_ok=True)
        raise


# The cache payload is a versioned envelope around the local-stats dict, so a
# corrupted or foreign-shaped file is a cache miss (rescan + rewrite) instead
# of a crash or a garbage record.
def read_cached_stats(cache_file, max_age_seconds):
    cached = read_fresh_json(cache_file, max_age_seconds)
    if not isinstance(cached, dict) or cached.get("schemaVersion") != 1:
        return None
    # today* fields only mean "today" on the day they were scanned. A cache
    # from another local date (midnight passed, or the clock moved) is a miss,
    # not merely old, whatever its mtime says.
    if cached.get("scanDate") != today:
        return None
    stats = cached.get("stats")
    if not isinstance(stats, dict):
        return None
    if not all(key in stats for key in ("todayPrompts", "todayTotalTokens", "recentDays", "activeDates", "modelUsage")):
        return None
    return stats


def write_cached_stats(cache_file, stats):
    try:
        write_json(cache_file, {"schemaVersion": 1, "scanDate": today, "stats": stats})
    except Exception as exc:
        print(f"CodexUsage: could not write usage cache ({exc})", file=sys.stderr)


def local_stats():
    """Snapshot the aggregated local usage into the record's stats dict."""
    return {
        "todayPrompts": today_prompts,
        "todaySessions": len(today_sessions),
        "todayTotalTokens": today_total_tokens,
        "todayTokensByModel": today_tokens_by_model,
        "recentDays": [recent[day] for day in recent_dates],
        "totalPrompts": total_prompts,
        "totalSessions": len(total_sessions),
        # Native session files use a 30-day modification-time scan window;
        # pi/OMP and OpenCode include all available history.
        "activeDays": len(active_days),
        "activeDates": sorted(active_days),
        "modelUsage": model_usage,
    }


def run_local_scans():
    # A cache-layer failure can restart scanning in this same process.
    global today_prompts, today_total_tokens, total_prompts
    today_prompts = today_total_tokens = total_prompts = 0
    today_tokens_by_model.clear()
    model_usage.clear()
    today_sessions.clear()
    active_days.clear()
    total_sessions.clear()
    seen_pi_messages.clear()
    for bucket in recent.values():
        bucket["messageCount"] = 0
    pi_complete = scan_pi_sessions()
    native_complete = scan_native_codex_sessions()
    opencode_complete = scan_opencode_sessions()
    return local_stats(), pi_complete and native_complete and opencode_complete


def cached_local_stats(max_age):
    """Local stats, with the cache as a pure optimization.

    The cache must never take the collector down: any cache-layer failure
    (unwritable cache root, lock errors, disk full) degrades to a direct scan
    and a warning on stderr. The JSON record is the contract; the cache is not.
    """
    try:
        return _cached_local_stats(max_age)
    except Exception as exc:
        print(f"CodexUsage: cache unavailable ({exc}); scanning directly", file=sys.stderr)
        stats, _ = run_local_scans()
        return stats


def _cached_local_stats(max_age):
    cache_file, lock_file = scan_cache_paths()

    cached = read_cached_stats(cache_file, max_age)
    if cached is not None:
        return cached

    with lock_file.open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        cached = read_cached_stats(cache_file, max_age)
        if cached is not None:
            return cached
        stats, complete = run_local_scans()
        # An interrupted scan still serves this run, but caching it would
        # suppress the missing usage for every reader until the cache expires.
        if complete:
            write_cached_stats(cache_file, stats)
        return stats


def rpc_request(proc, request_id, method, params=None, timeout=8):
    payload = {"id": request_id, "method": method, "params": params or {}}
    proc.stdin.write((json.dumps(payload) + "\n").encode("utf-8"))
    proc.stdin.flush()
    deadline = time.monotonic() + timeout
    pending = b""
    while time.monotonic() < deadline:
        ready, _, _ = select.select([proc.stdout], [], [], max(0, deadline - time.monotonic()))
        if not ready:
            continue
        chunk = os.read(proc.stdout.fileno(), 65536)
        if not chunk:
            raise RuntimeError(f"{method}: Codex app-server closed its output")
        pending += chunk
        while b"\n" in pending:
            line, pending = pending.split(b"\n", 1)
            try:
                message = json.loads(line)
            except (ValueError, UnicodeError):
                continue
            if not isinstance(message, dict) or message.get("id") != request_id:
                continue
            if "error" in message:
                error = message["error"]
                detail = error.get("message", str(error)) if isinstance(error, dict) else str(error)
                raise RuntimeError(f"{method}: {detail}")
            if not isinstance(message.get("result"), dict):
                raise RuntimeError(f"{method}: invalid RPC result")
            return message["result"]
    raise TimeoutError(f"{method}: timed out after {timeout}s")


def limit_window(window):
    if not isinstance(window, dict):
        return None
    used = window.get("usedPercent")
    if used is None:
        return None
    mins = number(window.get("windowDurationMins"))
    if mins == 10080:
        label = "Weekly (7-day)"
    elif mins and mins % 60 == 0:
        label = f"{mins // 60}h window"
    elif mins:
        label = f"{mins}m window"
    else:
        label = "Limit"
    reset = window.get("resetsAt")
    return {
        "label": label,
        "percent": max(0.0, min(1.0, float(used) / 100.0)),
        "resetsAt": datetime.fromtimestamp(number(reset), timezone.utc).isoformat() if reset else "",
    }


def fetch_codex_rpc():
    result = {"limits": [], "tierLabel": "", "usageStatusText": "", "authHelpText": ""}
    codex = find_command("codex")
    if not codex:
        result["usageStatusText"] = "Codex unavailable"
        result["authHelpText"] = "Install the Codex CLI and make codex available in PATH."
        return result

    try:
        proc = subprocess.Popen(
            [codex, "-s", "read-only", "-a", "on-request", "app-server"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            bufsize=0,
            env=ENV,
        )
    except OSError as exc:
        result["usageStatusText"] = "Codex unavailable"
        result["authHelpText"] = str(exc)
        print(f"CodexUsage: {exc}", file=sys.stderr)
        return result

    try:
        rpc_request(proc, 1, "initialize", {"clientInfo": {"name": "quickshell-codex-usage", "version": "1"}}, timeout=8)
        proc.stdin.write(b'{"method":"initialized","params":{}}\n')
        proc.stdin.flush()
        account_result = rpc_request(proc, 2, "account/read", timeout=4)
        if "account" not in account_result:
            raise RuntimeError("account/read: missing account in RPC result")
        account = account_result["account"]
        if account is None or account == {}:
            result["usageStatusText"] = "Codex not signed in"
            result["authHelpText"] = AUTH_HELP
            return result
        if not isinstance(account, dict):
            raise RuntimeError("account/read: invalid account in RPC result")
        plan = account.get("planType") or account.get("type") or ""
        result["tierLabel"] = str(plan) if plan else ""

        limits_result = rpc_request(proc, 3, "account/rateLimits/read", timeout=4)
        limits = limits_result.get("rateLimits")
        if not isinstance(limits, dict) or not limits:
            raise RuntimeError("account/rateLimits/read: no rate limits returned")
        plan = limits.get("planType") or plan
        result["tierLabel"] = str(plan) if plan else ""
        for window in (limits.get("primary"), limits.get("secondary")):
            entry = limit_window(window)
            if entry:
                result["limits"].append(entry)
        if not result["limits"]:
            result["usageStatusText"] = "Codex limits unavailable"
            result["authHelpText"] = "No usage windows are available for this Codex account."
    except Exception as exc:
        result["limits"] = []
        result["usageStatusText"] = "Codex limits unavailable"
        result["authHelpText"] = str(exc)
        print(f"CodexUsage: {exc}", file=sys.stderr)
    finally:
        try:
            proc.terminate()
            proc.wait(timeout=1)
        except (OSError, subprocess.TimeoutExpired):
            proc.kill()
            proc.wait()
        finally:
            proc.stdin.close()
            proc.stdout.close()
    return result


def main():
    parser = argparse.ArgumentParser()
    # Limits are always fetched live. --force rescans local usage; limits-only
    # may reuse a recent local scan instead.
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--limits-only", action="store_true")
    args = parser.parse_args()

    max_age = 0 if args.force else (LIMITS_ONLY_REUSE_SECONDS if args.limits_only else SCAN_REUSE_SECONDS)
    stats = cached_local_stats(max_age)
    rpc = fetch_codex_rpc()

    record = {
        "schemaVersion": 1,
        "id": AGENT_ID,
        "name": AGENT_NAME,
        "updatedAt": datetime.now(timezone.utc).isoformat(),
        "ready": True,
        "hasLocalStats": True,
    }
    record.update(stats)
    record.update(rpc)
    print(json.dumps(record, separators=(",", ":")))


if __name__ == "__main__":
    main()
