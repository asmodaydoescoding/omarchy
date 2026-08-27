import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path


HELPER = Path(__file__).resolve().parents[1] / "ai-core" / "hermes-safe-io"


class HermesSafeIOTests(unittest.TestCase):
    def run_helper(self, *arguments, timeout=3):
        started = time.monotonic()
        try:
            result = subprocess.run(
                [str(HELPER), *map(str, arguments)],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
                timeout=timeout,
            )
        except subprocess.TimeoutExpired as exc:
            self.fail(f"helper hung after {timeout} seconds: {exc}")
        self.assertLess(time.monotonic() - started, timeout)
        return result

    def assert_rejected(self, *arguments):
        result = self.run_helper(*arguments)
        self.assertNotEqual(result.returncode, 0)
        return result

    def test_read_regular_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "input"
            path.write_bytes(b"hermes-safe-io\n")

            result = self.run_helper("read", 1024, path)

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, b"hermes-safe-io\n")
        self.assertEqual(result.stderr, b"")

    def test_read_missing_path_is_rejected_without_hanging(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "missing"
            result = self.assert_rejected("read", 1024, path)

        self.assertIn(b"safe read refused", result.stderr)

    @unittest.skipUnless(hasattr(os, "symlink"), "symlinks unavailable")
    def test_read_symlink_is_rejected_without_hanging(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "target"
            link = Path(directory) / "link"
            target.write_bytes(b"must not be followed")
            os.symlink(target, link)

            result = self.assert_rejected("read", 1024, link)

        self.assertIn(b"safe read refused", result.stderr)
        self.assertEqual(result.stdout, b"")

    def test_read_oversized_file_is_rejected_without_hanging(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "large"
            path.write_bytes(b"0123456789")

            result = self.assert_rejected("read", 9, path)

        self.assertIn(b"oversized file", result.stderr)
        self.assertEqual(result.stdout, b"")

    def test_run_bounds_stdout_and_suppresses_stderr(self):
        script = (
            "import sys; "
            "sys.stderr.write('secret stderr'); "
            "sys.stdout.write('bounded stdout')"
        )
        result = self.run_helper("run", 2, 1024, "--", sys.executable, "-c", script)

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, b"bounded stdout")
        self.assertEqual(result.stderr, b"")

    def test_run_propagates_nonzero_exit_without_emitting_output(self):
        script = "import sys; sys.stdout.write('partial'); sys.exit(7)"
        result = self.assert_rejected(
            "run", 2, 1024, "--", sys.executable, "-c", script
        )

        self.assertEqual(result.returncode, 7)
        self.assertEqual(result.stdout, b"")
        self.assertIn(b"subprocess exited 7", result.stderr)

    def test_run_timeout_is_rejected_without_hanging(self):
        script = "import time; time.sleep(2)"
        result = self.assert_rejected(
            "run", 0.1, 1024, "--", sys.executable, "-c", script
        )

        self.assertIn(b"timed out", result.stderr)

    def test_run_output_overflow_is_rejected_without_hanging(self):
        script = "import sys; sys.stdout.write('x' * 65537); sys.stdout.flush()"
        result = self.assert_rejected(
            "run", 2, 32, "--", sys.executable, "-c", script
        )

        self.assertIn(b"output exceeded byte limit", result.stderr)
        self.assertEqual(result.stdout, b"")


if __name__ == "__main__":
    unittest.main()
