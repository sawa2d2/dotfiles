#!/usr/bin/env python3
"""Regression checks for tmux pane forwarding."""
import importlib.util
import tempfile
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


class PickTests(unittest.TestCase):
    """The display-panes picker: source pane first, then destination."""

    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        patcher = patch.object(tchat, "STATE", Path(tmp.name))
        patcher.start()
        self.addCleanup(patcher.stop)
        for name, kwargs in (("pane", {"side_effect": lambda p: p}), ("show_picker", {})):
            patcher = patch.object(tchat, name, **kwargs)
            setattr(self, name, patcher.start())
            self.addCleanup(patcher.stop)

    def start(self, action="once"):
        # As `tchat once` with no panes does before showing the first picker.
        with patch.object(tchat.uuid, "uuid4") as uuid4, \
                patch.dict(tchat.os.environ, {"TMUX": "x"}), \
                patch.object(tchat.sys, "argv", ["tchat", action]):
            uuid4.return_value.hex = "tok"
            tchat.main()
        self.show_picker.assert_called_once_with("tok", "source")

    def test_source_then_destination_runs_action(self):
        self.start("on")
        tchat.pick("tok", "source", "%1")
        self.show_picker.assert_called_with("tok", "destination")
        with patch.object(tchat.subprocess, "Popen") as popen:
            tchat.pick("tok", "destination", "%2")
        self.assertEqual(popen.call_args.args[0][2:], ["on", "%1", "%2"])
        self.assertFalse(tchat.pick_file("tok").exists())

    def test_same_pane_twice_does_nothing(self):
        self.start()
        tchat.pick("tok", "source", "%1")
        with patch.object(tchat.subprocess, "Popen") as popen:
            tchat.pick("tok", "destination", "%1")
        popen.assert_not_called()

    def test_expired_selection_is_dropped(self):
        tchat.STATE.mkdir(exist_ok=True)
        tchat.pick_file("tok").write_text("once\n0\n")
        tchat.pick("tok", "source", "%1")
        self.show_picker.assert_not_called()
        self.assertFalse(tchat.pick_file("tok").exists())


if __name__ == "__main__":
    unittest.main()
