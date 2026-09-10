#!/usr/bin/env python3
# Adapted from Omarchy's network panel/status sampler.
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
"""One bounded, read-only sample of data missing from Quickshell.Networking."""

import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import time


children = set()
environment = dict(os.environ, LC_ALL="C")


def stop(_signum, _frame):
    for child in tuple(children):
        if child.poll() is None:
            child.kill()
        child.wait()
    raise SystemExit(0)


signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)


def run(arguments):
    child = subprocess.Popen(arguments, stdout=subprocess.PIPE,
                             stderr=subprocess.DEVNULL, text=True, env=environment)
    children.add(child)
    try:
        output, _ = child.communicate(timeout=2)
        return output if child.returncode == 0 else ""
    except subprocess.TimeoutExpired:
        child.kill()
        child.communicate()
        return ""
    finally:
        children.discard(child)


def ip(*arguments):
    output = run(["ip", "-j", *arguments])
    return json.loads(output) if output else []


def route():
    routes = ip("route", "get", "1.1.1.1")
    return routes[0] if routes else {}


def counter(path):
    try:
        return int(path.read_text().strip())
    except (OSError, ValueError):
        return None


def probe(interface, host):
    child = subprocess.Popen(["ping", "-n", "-I", interface, "-c", "1", "-W", "1", "-w", "2", host],
                             stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                             text=True, env=environment)
    children.add(child)
    return child


def probe_result(child):
    try:
        output, _ = child.communicate(timeout=2.5)
        if child.returncode not in (0, 1):
            return "unavailable"
        match = re.search(r"time[=<]([\d.]+)", output)
        return float(match[1]) if match else None
    except subprocess.TimeoutExpired:
        child.kill()
        child.communicate()
        return None
    finally:
        children.discard(child)


def sample():
    current = route()
    interface = current.get("dev") or (sys.argv[1] if len(sys.argv) > 1 else "")
    if not interface:
        return {}
    # Interface names come from the kernel/native service, never a shell expression.
    if "/" in interface or interface in (".", ".."):
        raise ValueError("Invalid interface")
    addresses = ip("address", "show", "dev", interface)
    if not addresses:
        return {}
    gateway = current.get("gateway", "")
    if not gateway:
        defaults = ip("route", "show", "default", "dev", interface)
        gateway = defaults[0].get("gateway", "") if defaults else ""
    values = addresses[0].get("addr_info", [])
    addresses_text = [f"{entry['local']}/{entry['prefixlen']}" for entry in values
                      if entry.get("scope") == "global"]
    base = Path("/sys/class/net") / interface
    result = {
        "iface": interface,
        "wireless": (base / "wireless").is_dir(),
        "addresses": addresses_text,
        "gateway": gateway,
        "rx": counter(base / "statistics/rx_bytes"),
        "tx": counter(base / "statistics/tx_bytes"),
        "sampleTime": time.monotonic(),
        "dns": [],
    }
    if shutil.which("nmcli"):
        output = run(["nmcli", "--terse", "--escape", "no", "--fields", "IP4.DNS,IP6.DNS",
                      "device", "show", interface])
        result["dns"] = list(dict.fromkeys(line.split(":", 1)[1].strip()
                                           for line in output.splitlines() if ":" in line))
    else:
        result["dnsError"] = "nmcli unavailable"
    if shutil.which("ping"):
        probes = {"internetPing": probe(interface, "1.1.1.1")}
        if gateway:
            probes["routerPing"] = probe(interface, gateway)
        for name, child in probes.items():
            result[name] = probe_result(child)
    else:
        result["pingError"] = "ping unavailable"
    # Never attribute a completed probe to a route that changed mid-sample.
    after = route()
    if (after.get("dev"), after.get("gateway")) != (current.get("dev"), current.get("gateway")):
        return {"stale": True}
    return result


if __name__ == "__main__":
    try:
        print(json.dumps(sample(), allow_nan=False))
    except (OSError, ValueError, KeyError) as error:
        print(json.dumps({"error": str(error)}))
        sys.exit(1)
