#!/usr/bin/env python3
"""Regression tests for tmux-session's allowlisted process restoration."""
import importlib.util
from importlib.machinery import SourceFileLoader
import unittest
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


if __name__ == "__main__":
    unittest.main()
