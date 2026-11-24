import sys
import unittest
from pathlib import Path
from unittest.mock import Mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "lib" / "Viper"))

from ViperGnmi import ViperGnmi


class Channel:
    def __init__(self, chunks, error=b""):
        self.chunks = list(chunks)
        self.error = error
        self.closed = False

    def recv_ready(self):
        return bool(self.chunks)

    def recv(self, size):
        return self.chunks.pop(0)

    def recv_stderr_ready(self):
        return bool(self.error)

    def recv_stderr(self, size):
        error, self.error = self.error, b""
        return error

    def exit_status_ready(self):
        return False

    def close(self):
        self.closed = True


class SubscriptionTest(unittest.TestCase):
    def setUp(self):
        self.gnmi = ViperGnmi()
        self.gnmi._ensure_connected = Mock()
        self.gnmi._gnmic_argv = Mock(return_value=["gnmic", "sub"])
        self.gnmi._save_log = Mock()

    def start(self, channel):
        self.gnmi._connection = Mock()
        self.gnmi._connection.exec_command.return_value = (None, Mock(channel=channel), None)
        self.gnmi.start_subscription("status", timeout=0.1)

    def test_fragmented_and_concatenated_responses(self):
        channel = Channel([b'{"sync-res', b'ponse":true}{"status":"IN_', b'PROGRESS"}{"status":"ALIGNED"}'])
        self.start(channel)
        self.assertEqual(self.gnmi.next_subscription_response(timeout=0.1)["status"], "IN_PROGRESS")
        self.assertEqual(self.gnmi.next_subscription_response(timeout=0.1)["status"], "ALIGNED")
        self.gnmi.stop_subscription()
        self.assertTrue(channel.closed)

    def test_failed_sync_closes_channel(self):
        channel = Channel([b'{"error":"rejected"}'])
        with self.assertRaisesRegex(AssertionError, "sync response"):
            self.start(channel)
        self.assertTrue(channel.closed)
        self.assertIsNone(self.gnmi._subscription)

    def test_timeout_reports_stderr(self):
        channel = Channel([b'{"sync-response":true}'], error=b"subscription failed")
        self.start(channel)
        with self.assertRaisesRegex(TimeoutError, "subscription failed"):
            self.gnmi.next_subscription_response(timeout=0.1)
        self.gnmi.stop_subscription()


if __name__ == "__main__":
    unittest.main()
