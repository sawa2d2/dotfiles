#!/usr/bin/env python3
"""Regression tests for tmux-session's allowlisted process restoration."""
from contextlib import redirect_stderr, redirect_stdout
import importlib.util
import io
import json
import tempfile
from importlib.machinery import SourceFileLoader
import unittest
from unittest.mock import patch
import subprocess
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "bin/tmux-bin/tmux-session"
spec = importlib.util.spec_from_loader("tmux_session", SourceFileLoader("tmux_session", str(SCRIPT)))
tmux_session = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tmux_session)


class RestoreCommandTests(unittest.TestCase):
    def test_direct_bob(self):
        self.assertEqual(tmux_session.restorable_command({"command": "bob"}), "bob")

    def test_node_bob_resume(self):
        pane = {
            "command": "node",
            "argv": [
                "node",
                "/home/ts/.nvm/versions/node/v24.22.0/bin/bob",
                "chat",
                "--resume",
                "latest",
                "--auto-approve",
            ],
        }
        self.assertEqual(
            tmux_session.restorable_command(pane),
            "bob chat --resume latest --auto-approve",
        )

    def test_legacy_yolo_resume_restores_plain_bob(self):
        # The agent-config bob launcher resumes the latest task by default.
        pane = {
            "command": "node",
            "argv": ["node", "/tmp/bob", "chat", "--resume", "latest", "--yolo"],
        }
        self.assertEqual(tmux_session.restorable_command(pane), "bob")

    def test_unapproved_bob_arguments_are_not_replayed(self):
        pane = {"command": "node", "argv": ["node", "/tmp/bob", "--dangerous", "x"]}
        self.assertEqual(tmux_session.restorable_command(pane), "bob")

    def test_unrelated_node_process_is_not_restarted(self):
        pane = {"command": "node", "argv": ["node", "/tmp/server.js"]}
        self.assertIsNone(tmux_session.restorable_command(pane))

    def test_shell_is_not_restarted(self):
        self.assertIsNone(
            tmux_session.restorable_command({"command": "bash", "argv": ["-bash"]})
        )


class MacOSProcessTests(unittest.TestCase):
    def test_node_bob_foreground_group(self):
        rows = (
            " 500 500 -zsh\n"
            " 610 610 node /Users/test/.nvm/bin/bob chat --resume latest --auto-approve\n"
            " 611 610 helper --background\n"
            " 700 700 other\n"
        )
        self.assertEqual(
            tmux_session.macos_process_rows(rows, 610)[0],
            (610, ["node", "/Users/test/.nvm/bin/bob", "chat", "--resume", "latest", "--auto-approve"]),
        )

    def test_macos_foreground_lookup_and_restore(self):
        outputs = [
            subprocess.CompletedProcess([], 0, "610\n", ""),
            subprocess.CompletedProcess([], 0,
                "500 500 -zsh\n610 610 node /Users/test/.nvm/bin/bob chat --resume latest --auto-approve\n", ""),
        ]
        with patch.object(tmux_session.subprocess, "run", side_effect=outputs) as run:
            pane = tmux_session.macos_foreground_process(500, "node")
        self.assertEqual(run.call_count, 2)
        self.assertEqual(pane["command"], "node")
        self.assertEqual(
            tmux_session.restorable_command(pane),
            "bob chat --resume latest --auto-approve",
        )

    def test_macos_ps_failure_is_nonfatal(self):
        with patch.object(
            tmux_session.subprocess, "run",
            side_effect=subprocess.CalledProcessError(1, ["ps"]),
        ):
            self.assertEqual(
                tmux_session.macos_foreground_process(500, "node"),
                {"command": "node", "argv": None},
            )

    def test_macos_dispatch(self):
        with patch.object(tmux_session.sys, "platform", "darwin"):
            with patch.object(
                tmux_session, "macos_foreground_process",
                return_value={"command": "node", "argv": ["node", "bob"]},
            ) as probe:
                self.assertEqual(
                    tmux_session.foreground_process(500, "node"),
                    {"command": "node", "argv": ["node", "bob"]},
                )
                probe.assert_called_once_with(500, "node")


class SaveHistoryTests(unittest.TestCase):
    def test_save_keeps_newest_history_snapshots(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            snapshots = [
                {"version": 1, "session": "a/b", "saved_at": str(i), "windows": [{}]}
                for i in range(7)
            ]
            with patch.object(tmux_session, "DIR", root), patch.object(
                tmux_session, "snapshot", side_effect=snapshots
            ), redirect_stdout(io.StringIO()):
                for _ in snapshots:
                    tmux_session.save("a/b")

            latest = json.loads((root / "a%2Fb.json").read_text())
            self.assertEqual(latest["saved_at"], "6")
            history = sorted((root / "history" / "a%2Fb").glob("*.json"))
            self.assertEqual(
                [json.loads(p.read_text())["saved_at"] for p in history],
                ["2", "3", "4", "5", "6"],
            )
            # History must not appear as a session snapshot next to the main files.
            self.assertEqual(sorted(p.name for p in root.glob("*.json")), ["a%2Fb.json"])


class MissingDirectoryTests(unittest.TestCase):
    def test_existing_directory_is_kept(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(tmux_session.working_directory(tmp), tmp)

    def test_missing_directory_falls_back_to_home(self):
        with redirect_stderr(io.StringIO()) as err:
            cwd = tmux_session.working_directory("/nonexistent/tload-test")
        self.assertEqual(cwd, str(Path.home()))
        self.assertIn("/nonexistent/tload-test", err.getvalue())

    def test_activate_uses_home_and_skips_command_for_missing_directory(self):
        options = {"@tload_cwd": "/nonexistent/tload-test", "@tload_command": "nvim"}

        def run(args, **kwargs):
            if args[:2] == ["tmux", "show-options"] and args[-1] == "@tload_pending":
                return subprocess.CompletedProcess(args, 0, "1\n", "")
            value = options.get(args[-1])
            return subprocess.CompletedProcess(args, 0 if value else 1, f"{value}\n", "")

        calls = []

        def tm(*args):
            calls.append(args)
            return "/bin/zsh" if args[0] == "show-options" else ""

        with (
            patch.object(tmux_session.subprocess, "run", side_effect=run),
            patch.object(tmux_session, "records", return_value=[("%1",)]),
            patch.object(tmux_session, "tm", side_effect=tm),
            redirect_stderr(io.StringIO()),
        ):
            tmux_session.activate("@1")

        self.assertIn(
            ("respawn-pane", "-k", "-c", str(Path.home()), "-t", "%1", "/bin/zsh"),
            calls,
        )
        self.assertFalse(any(call[0] == "send-keys" for call in calls))


if __name__ == "__main__":
    unittest.main()
