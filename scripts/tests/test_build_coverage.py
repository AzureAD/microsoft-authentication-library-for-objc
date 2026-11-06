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

# Execute build definitions and CLI with mocked subprocesses only: these tests
# must never start Xcode builds, tests, simulators or DerivedData cleanup.
import ast
import contextlib
import io
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch


ROOT = Path(__file__).resolve().parents[2]
tree = ast.parse((ROOT / "build.py").read_text())
definitions = []
for statement in tree.body:
    if isinstance(statement, ast.Assign) and any(
        isinstance(target, ast.Name) and target.id == "clean"
        for target in statement.targets
    ):
        break
    definitions.append(statement)
namespace = {}
with patch.dict(sys.modules, {"device_guids": Mock()}):
    exec(compile(ast.Module(body=definitions, type_ignores=[]), "build.py", "exec"), namespace)


class BuildCoverageTests(unittest.TestCase):
    def target(self, name="macFramework", coverage=True):
        spec = next(item for item in namespace["target_specifiers"] if item["target"] == name)
        return namespace["BuildTarget"](spec, enable_coverage=coverage)

    def test_build_and_test_share_scheme_local_data_and_only_test_has_result_bundle(self):
        ios, mac = self.target("iosFramework"), self.target()
        for target in [ios, mac]:
            build = shlex.split(target.xcodebuild_command("build", False))
            test = shlex.split(target.xcodebuild_command("test", False))
            settings = shlex.split(target.xcodebuild_command(None, False))
            self.assertIn("build-for-testing", build)
            self.assertIn("test-without-building", test)
            for command in [build, test, settings]:
                self.assertEqual(target.coverage_derived_data, command[command.index("-derivedDataPath") + 1])
            for command in [build, test]:
                self.assertEqual("YES", command[command.index("-enableCodeCoverage") + 1])
            self.assertNotIn("-resultBundlePath", build)
            self.assertEqual(target.coverage_result, test[test.index("-resultBundlePath") + 1])
        self.assertNotEqual(ios.coverage_derived_data, mac.coverage_derived_data)
        self.assertNotEqual(ios.coverage_result, mac.coverage_result)
        self.assertIn(namespace["ios_sim_dest"], ios.xcodebuild_command("test", False))

    def test_plain_builds_and_noncoverage_operations_are_preserved(self):
        for target in [self.target(coverage=False), self.target("iosTestApp"),
                       self.target("sampleIosApp"), self.target("sampleIosAppSwift"),
                       self.target("visionOSFramework")]:
            command = target.xcodebuild_command("build", False)
            self.assertNotIn("-derivedDataPath", command)
            self.assertNotIn("-resultBundlePath", command)
        self.assertIn("-enableCodeCoverage YES", self.target(coverage=False).xcodebuild_command("test", False))
        self.assertNotIn("-enableCodeCoverage", self.target("iosFramework", False).xcodebuild_command("test", False))

    def test_export_precedes_later_sample_build(self):
        first, sample = self.target("iosFramework"), self.target("sampleIosApp")
        with patch.object(subprocess, "call", return_value=0) as call:
            first.do_operation("build")
            first.do_operation("test")
            sample.do_operation("build")
        commands = [args.args[0] for args in call.call_args_list]
        self.assertEqual(4, len(commands))
        self.assertEqual(["ruby", "scripts/coverage.rb", "export", first.scheme,
                          first.coverage_derived_data, first.coverage_result], commands[2])
        self.assertIn("SampleAppiOS", commands[3])

    def test_failed_tests_still_export_and_keep_test_exit_code(self):
        target = self.target()
        with patch.object(subprocess, "call", side_effect=[65, 1]) as call:
            self.assertEqual(65, target.do_operation("test"))
        self.assertEqual(2, call.call_count)
        self.assertTrue(target.failed)

    def test_failed_export_fails_target_without_blocking_independent_target(self):
        first, second = self.target("iosFramework"), self.target()
        with patch.object(subprocess, "call", side_effect=[0, 1, 0, 0]) as call:
            self.assertEqual(1, first.do_operation("test"))
            self.assertEqual(0, second.do_operation("test"))
        self.assertTrue(first.failed)
        self.assertFalse(second.failed)
        self.assertEqual(4, call.call_count)

    def test_noncoverage_test_does_not_export(self):
        target = self.target(coverage=False)
        with patch.object(subprocess, "call", return_value=0) as call:
            self.assertEqual(0, target.do_operation("test"))
        self.assertEqual(1, call.call_count)

    def test_coverage_mode_does_not_run_legacy_threshold_or_host_cpu_selection(self):
        target = self.target()
        with patch.object(subprocess, "call") as call, \
             patch.object(subprocess, "check_output") as check:
            self.assertEqual(0, target.do_operation("codecov"))
        call.assert_not_called()
        check.assert_not_called()

    def test_existing_targets_operations_and_platforms_are_unchanged(self):
        specs = namespace["target_specifiers"]
        tested = [spec["scheme"] for spec in specs if "test" in spec["operations"]]
        self.assertEqual(["MSAL (iOS Framework)", "MSAL (Mac Framework)"], tested)
        self.assertEqual(6, len(specs))
        self.assertEqual(["build"], self.target("visionOSFramework").operations)
        self.assertEqual(["build", "test", "codecov"], self.target().operations)

    def test_preparation_clears_only_own_stale_coverage_not_other_scheme(self):
        original = os.getcwd()
        with tempfile.TemporaryDirectory() as directory:
            try:
                os.chdir(directory)
                target, second = self.target("iosFramework"), self.target()
                for item in [target, second]:
                    paths = [Path(item.coverage_result), Path(item.coverage_derived_data) / "Build/ProfileData",
                             Path("build/coverage/reports") / item.scheme,
                             Path("build/coverage/diagnostics") / item.scheme]
                    for path in paths:
                        path.mkdir(parents=True)
                        (path / "old").write_text("stale")
                product = Path(target.coverage_derived_data) / "Build/Products/MSAL.framework"
                product.mkdir(parents=True)
                target.prepare_coverage()
                self.assertFalse(Path(target.coverage_result).exists())
                self.assertFalse((Path(target.coverage_derived_data) / "Build/ProfileData").exists())
                self.assertFalse((Path("build/coverage/reports") / target.scheme).exists())
                self.assertTrue(Path(second.coverage_result).exists())
                self.assertTrue((Path("build/coverage/reports") / second.scheme).exists())
                self.assertTrue(product.exists())
            finally:
                os.chdir(original)

    def test_main_records_export_failure_but_runs_later_existing_targets(self):
        commands = []

        def execute(command, **kwargs):
            commands.append(command)
            return 1 if isinstance(command, list) and command[:3] == ["ruby", "scripts/coverage.rb", "export"] else 0

        original = os.getcwd()
        with tempfile.TemporaryDirectory() as directory:
            try:
                os.chdir(directory)
                script_namespace = {}
                device_guids = Mock()
                device_guids.get_ios.return_value = "fixture-device"
                with patch.dict(sys.modules, {"device_guids": device_guids}), \
                     patch.object(sys, "argv", ["build.py", "--coverage", "--no-clean", "--targets",
                                               "iosFramework", "iosTestApp", "sampleIosApp", "sampleIosAppSwift"]), \
                     patch.object(subprocess, "call", side_effect=execute), \
                     patch.object(subprocess, "Popen"), patch.object(subprocess, "check_output"), \
                     contextlib.redirect_stdout(io.StringIO()):
                    with self.assertRaises(SystemExit) as result:
                        exec(compile(tree, "build.py", "exec"), script_namespace)
                script_namespace["status_file"].close()
                self.assertEqual(1, result.exception.code)
                self.assertEqual("1", Path("status.txt").read_text())
                exports = [command for command in commands if isinstance(command, list)]
                self.assertEqual(1, len(exports))
                self.assertIn("SampleAppiOS-Swift", commands[-1])
            finally:
                os.chdir(original)


if __name__ == "__main__":
    unittest.main()
