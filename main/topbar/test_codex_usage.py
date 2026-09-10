import json
import os
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime
from pathlib import Path


class CodexUsageTests(unittest.TestCase):
    def test_repeated_notifications_do_not_double_count_cached_or_reasoning_tokens(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            home = Path(temporary_directory)
            sessions = home / ".codex" / "sessions"
            sessions.mkdir(parents=True)
            usage = {
                "input_tokens": 100,
                "cached_input_tokens": 60,
                "output_tokens": 20,
                "reasoning_output_tokens": 10,
                "total_tokens": 120,
            }

            def event(multiplier):
                return {
                    "type": "event_msg",
                    "timestamp": datetime.now().astimezone().isoformat(),
                    "payload": {
                        "type": "token_count",
                        "info": {
                            "last_token_usage": usage,
                            "total_token_usage": {
                                key: value * multiplier for key, value in usage.items()
                            },
                        },
                    },
                }

            events = [
                {"type": "turn_context", "payload": {"model": "gpt-codex"}},
                event(1), event(1), event(2), event(2),
            ]
            (sessions / "session.jsonl").write_text(
                "\n".join(json.dumps(event) for event in events) + "\n{incomplete",
                encoding="utf-8",
            )
            environment = dict(
                os.environ, HOME=str(home), CODEX_HOME=str(home / ".codex"),
                XDG_CACHE_HOME=str(home / "cache"), XDG_DATA_HOME=str(home / "data"),
                PATH="",
            )
            result = subprocess.run(
                [sys.executable, str(Path(__file__).with_name("CodexUsage.py")), "--force"],
                env=environment, check=True, capture_output=True, text=True, timeout=10,
            )
            record = json.loads(result.stdout)
            self.assertEqual(record["todayTotalTokens"], 240)
            self.assertEqual(record["todayPrompts"], 2)
            self.assertEqual(record["todaySessions"], 1)
            self.assertEqual(record["recentDays"][-1]["messageCount"], 240)
            self.assertEqual(record["modelUsage"]["gpt-codex"], {
                "inputTokens": 80, "outputTokens": 40,
                "cacheReadInputTokens": 120, "cacheCreationInputTokens": 0,
            })
            # Local history remains useful when no Codex binary is installed.
            self.assertEqual(record["limits"], [])
            self.assertTrue(record["usageStatusText"])


if __name__ == "__main__":
    unittest.main()
