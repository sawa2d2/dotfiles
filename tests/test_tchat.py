#!/usr/bin/env python3
"""Regression checks for tmux pane forwarding."""
import importlib.util
from importlib.machinery import SourceFileLoader
from pathlib import Path
import unittest
from unittest.mock import call, patch

SCRIPT = Path(__file__).resolve().parents[1] / "bin/tmux-bin/tchat"
spec = importlib.util.spec_from_loader("tchat", SourceFileLoader("tchat", str(SCRIPT)))
tchat = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tchat)


class ForwardTests(unittest.TestCase):
    def test_literal_input_then_enter(self):
        with patch.object(tchat.subprocess, "run") as run:
            tchat.send("%2", "hello; rm -rf /")
        self.assertEqual(run.call_args_list, [
            call(["tmux", "send-keys", "-t", "%2", "-l", "--", "hello; rm -rf /"], check=True),
            call(["tmux", "send-keys", "-t", "%2", "Enter"], check=True),
        ])

    def test_empty_snapshot_not_sent(self):
        with patch.object(tchat, "send") as send:
            self.assertFalse(tchat.forward("%1", "%2", "  "))
            send.assert_not_called()

    def test_large_snapshot_is_bounded(self):
        self.assertLessEqual(len(tchat.payload("a" * 20000).encode()), tchat.MAX_BYTES)

    def test_utf8_boundary(self):
        text = "猫" * 5000
        self.assertLessEqual(len(tchat.payload(text).encode()), tchat.MAX_BYTES)

    def test_state_file_per_pane(self):
        self.assertNotEqual(tchat.state_file("%1"), tchat.state_file("%2"))


if __name__ == "__main__":
    unittest.main()
