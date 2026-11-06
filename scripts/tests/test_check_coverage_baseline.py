# Copyright (c) Microsoft Corporation.
# All rights reserved.
#
# This code is licensed under the MIT License.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

"""Focused warning-only baseline regressions; no Xcode commands."""

import importlib.util
import io
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    "check_coverage_baseline", Path(__file__).resolve().parents[1] / "check_coverage_baseline.py"
)
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)
IOS = "MSAL (iOS Framework)"
MAC = "MSAL (Mac Framework)"


class CoverageBaselineTests(unittest.TestCase):
    def setUp(self):
        self.temp = TemporaryDirectory(prefix="msal baseline ")
        self.addCleanup(self.temp.cleanup)
        self.report = Path(self.temp.name) / f"{IOS}.cobertura.xml"

    def write_report(self, covered="82", valid="100", rate="0"):
        self.report.write_text(
            f'<coverage lines-covered="{covered}" lines-valid="{valid}" line-rate="{rate}"/>',
            encoding="utf-8",
        )

    def run_check(self, minimum="82", suite=IOS, revision="abc123", report=None):
        output = io.StringIO()
        with redirect_stdout(output):
            code = checker.main([
                "--report", report or str(self.report), "--suite", suite,
                "--minimum", minimum, "--revision", revision,
            ])
        self.assertEqual(code, 0)
        return output.getvalue()

    def assert_warning(self, output):
        self.assertIn("##vso[task.logissue type=warning]", output)
        self.assertEqual(output.count("##vso[task.complete result=SucceededWithIssues;]"), 1)
        self.assertNotIn("result=Failed", output)

    def test_below_equal_and_above(self):
        for covered in ("81", "82", "83"):
            with self.subTest(covered=covered):
                self.write_report(covered)
                output = self.run_check()
                for detail in (IOS, f"{covered}/100", f"{covered}.000000", "minimum=82", "abc123"):
                    self.assertIn(detail, output)
                if covered == "81":
                    self.assert_warning(output)
                else:
                    self.assertIn("at or above minimum", output)
                    self.assertNotIn("##vso[", output)

    def test_exact_boundary_ignores_rate_and_rounded_display(self):
        self.write_report("81999999999", "100000000000", "1")
        output = self.run_check()
        self.assertIn("82.000000", output)
        self.assert_warning(output)
        self.write_report()
        self.assertNotIn("##vso[", self.run_check())
        self.assert_warning(self.run_check(minimum="82.000000000000001"))

    def test_minimum_endpoints_and_decimal_equality(self):
        for covered, minimum in (("0", "0"), ("100", "100"), ("82", "82.0")):
            self.write_report(covered)
            self.assertNotIn("##vso[", self.run_check(minimum=minimum))

    def test_independent_schemes_and_observed_baselines(self):
        self.write_report("80")
        self.assert_warning(self.run_check())
        self.assertNotIn("##vso[", self.run_check(minimum="79", suite=MAC))
        for suite, covered, valid, minimum in (
            (IOS, "13500", "15962", "82"), (MAC, "12527", "15283", "79"),
        ):
            self.write_report(covered, valid)
            self.assertNotIn("##vso[", self.run_check(minimum=minimum, suite=suite))
            self.assertEqual(int(minimum), int(covered) * 100 // int(valid) - 2)

    def test_missing_empty_malformed_and_wrong_root_are_unavailable(self):
        for content in (None, "", "<coverage", "<not-coverage/>"):
            if content is not None:
                self.report.write_text(content, encoding="utf-8")
            output = self.run_check()
            self.assert_warning(output)
            for detail in ("covered/valid=unavailable", "actual=unavailable", "minimum=82", "abc123"):
                self.assertIn(detail, output)
            self.assertNotIn("at or above minimum", output)
            self.assertNotIn("actual=0", output)

    def test_invalid_counts_are_unavailable(self):
        for covered, valid in (
            ("-1", "100"), ("101", "100"), ("0", "0"), ("0", "-1"), ("1.5", "100"),
            ("1", "1.5"), ("nan", "100"), ("1", "inf"), ("", "100"), ("1", ""), ("+1", "100"),
        ):
            self.write_report(covered, valid)
            output = self.run_check()
            self.assert_warning(output)
            self.assertIn("actual=unavailable", output)
        self.report.write_text('<coverage line-rate="1"/>', encoding="utf-8")
        self.assert_warning(self.run_check())

    def test_zero_with_valid_denominator_is_real_zero(self):
        self.write_report("0")
        output = self.run_check()
        self.assert_warning(output)
        self.assertIn("actual=0.000000", output)

    def test_glob_requires_exactly_one_xml(self):
        pattern = str(self.report.parent / "*.cobertura.xml")
        self.assert_warning(self.run_check(report=pattern))
        self.write_report()
        self.assertNotIn("##vso[", self.run_check(report=pattern))
        (self.report.parent / "duplicate.cobertura.xml").write_bytes(self.report.read_bytes())
        output = self.run_check(report=pattern)
        self.assert_warning(output)
        self.assertIn("found 2", output)
        self.assertIn("actual=unavailable", output)

    def test_invalid_minimum_fails_before_missing_report(self):
        for minimum in ("-1", "101", "NaN", "Infinity", "", "forty"):
            with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
                self.run_check(minimum=minimum)
            self.assertEqual(error.exception.code, 2)

    def test_io_and_programming_errors_are_not_warning_successes(self):
        self.write_report()
        for error in (PermissionError("unreadable"), RuntimeError("bug"), IsADirectoryError("directory")):
            with patch.object(checker.ET, "parse", side_effect=error), patch.object(checker, "warn") as warning:
                with self.assertRaises(type(error)):
                    self.run_check()
                warning.assert_not_called()
        with patch.object(checker.glob, "glob", side_effect=OSError("I/O")):
            with self.assertRaises(OSError):
                self.run_check()

    def test_report_disappearing_after_glob_warns_unavailable(self):
        self.write_report()
        with patch.object(checker.ET, "parse", side_effect=FileNotFoundError("removed")):
            output = self.run_check()
        self.assert_warning(output)
        self.assertIn("actual=unavailable", output)

    def test_logging_command_data_is_escaped(self):
        self.write_report("81")
        output = self.run_check(revision="abc%\r\n##vso[task.complete result=Succeeded;]")
        self.assertNotIn("\n##vso[task.complete result=Succeeded;]", output)
        self.assertIn("abc%AZP25%0D%0A", output)
        self.assert_warning(output)

    def test_cli_warning_exit_zero_and_config_failure(self):
        args = [sys.executable, checker.__file__, "--report", str(self.report),
                "--suite", IOS, "--revision", "abc123", "--minimum"]
        result = subprocess.run(args + ["82"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assert_warning(result.stdout)
        result = subprocess.run(args + ["bad"], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("task.complete", result.stdout)


if __name__ == "__main__":
    unittest.main()
