#!/usr/bin/env python3
"""Regression tests for tmux-session's allowlisted process restoration."""
import importlib.util
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
                "--yolo",
            ],
        }
        self.assertEqual(
            tmux_session.restorable_command(pane),
            "bob chat --resume latest --yolo",
        )

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
            " 610 610 node /Users/test/.nvm/bin/bob chat --resume latest --yolo\n"
            " 611 610 helper --background\n"
            " 700 700 other\n"
        )
        self.assertEqual(
            tmux_session.macos_process_rows(rows, 610)[0],
            (610, ["node", "/Users/test/.nvm/bin/bob", "chat", "--resume", "latest", "--yolo"]),
        )

    def test_macos_foreground_lookup_and_restore(self):
        outputs = [
            subprocess.CompletedProcess([], 0, "610\n", ""),
            subprocess.CompletedProcess([], 0,
                "500 500 -zsh\n610 610 node /Users/test/.nvm/bin/bob chat --resume latest --yolo\n", ""),
        ]
        with patch.object(tmux_session.subprocess, "run", side_effect=outputs) as run:
            pane = tmux_session.macos_foreground_process(500, "node")
        self.assertEqual(run.call_count, 2)
        self.assertEqual(pane["command"], "node")
        self.assertEqual(
            tmux_session.restorable_command(pane),
            "bob chat --resume latest --yolo",
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


if __name__ == "__main__":
    unittest.main()
