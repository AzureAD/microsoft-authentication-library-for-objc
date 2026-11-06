# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

import automation_coverage as coverage


class CoverageTests(unittest.TestCase):
    def test_xctestrun_formats_preserve_selection(self):
        target = {
            "BlueprintName": "InteractiveiOSTests", "IsUITestBundle": True,
            "SkipTestIdentifiers": ["A/testB"], "OnlyTestIdentifiers": ["A"],
        }
        modern = {"TestConfigurations": [{"TestTargets": [target]}]}
        self.assertIs(coverage.test_targets(modern)[0], target)
        legacy = {"InteractiveiOSTests": target, "__xctestrun_metadata__": {"FormatVersion": 1}}
        self.assertEqual(coverage.test_targets(legacy)[0], target)
        target["IsEnabled"] = False
        self.assertEqual(coverage.test_targets(modern), [])
        target["IsEnabled"] = True
        modern["TestConfigurations"][0]["IsEnabled"] = False
        self.assertEqual(coverage.test_targets(modern), [])

    def test_live_profile_is_not_a_final_snapshot(self):
        with tempfile.TemporaryDirectory() as temporary:
            profile = Path(temporary) / f"msal-signature-{os.getpid()}.profraw"
            profile.write_bytes(b"profile")
            with self.assertRaisesRegex(ValueError, "still alive"):
                coverage.profile_snapshot([profile])

    def test_prepare_only_changes_app_environment(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            products = root / "build/Build/Products"
            app = products / "Debug-iphonesimulator/Automation.app"
            (app / "Frameworks/MSAL.framework").mkdir(parents=True)
            (app / "Frameworks/MSAL.framework/MSAL").write_bytes(b"framework")
            (app / "Automation").write_bytes(b"app")
            (app / "Info.plist").write_bytes(plistlib.dumps({"CFBundleExecutable": "Automation"}))
            document = {
                name: {
                    "IsUITestBundle": True,
                    "UITargetAppPath": "__TESTROOT__/Debug-iphonesimulator/Automation.app",
                    "UITargetAppEnvironmentVariables": {"EXISTING": "keep"},
                    "SkipTestIdentifiers": ["A/testB"],
                    "EnvironmentVariables": {"RUNNER": "unchanged"},
                }
                for name in coverage.TARGETS
            }
            path = products / f"{coverage.SCHEME}.xctestrun"
            path.write_bytes(plistlib.dumps(document))
            output = root / "coverage"
            output.mkdir()
            with patch.object(coverage, "run", return_value="arm64"):
                coverage.prepare(root, output, coverage.SCHEME, "platform=iOS Simulator,name=phone")
            updated = plistlib.loads(path.read_bytes())
            for name in coverage.TARGETS:
                before = document[name]["UITargetAppEnvironmentVariables"]
                after = updated[name].pop("UITargetAppEnvironmentVariables")
                self.assertEqual(after["EXISTING"], before["EXISTING"])
                self.assertIn("%m-%p%c", after["LLVM_PROFILE_FILE"])
                self.assertEqual(updated[name], {
                    key: value for key, value in document[name].items()
                    if key != "UITargetAppEnvironmentVariables"
                })
            self.assertFalse(list(output.rglob("*.xctestrun")))
            with patch.object(coverage, "run", return_value="arm64"):
                with self.assertRaisesRegex(ValueError, "empty"):
                    coverage.prepare(root, output, coverage.SCHEME, "platform=iOS Simulator,name=phone")

    def test_missing_profile_fails_without_native_report(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            binary = root / "InteractiveiOSTests/products/MSAL"
            binary.parent.mkdir(parents=True)
            binary.write_bytes(b"binary")
            coverage.save_json(root / "provenance.json", {
                "source_root": str(root),
                "source_sha256": {},
                "scopes": [{"target": "InteractiveiOSTests", "binary_sha256": coverage.digest(binary)}],
            })
            with self.assertRaisesRegex(ValueError, "Missing/empty"):
                coverage.collect(root, root)
            self.assertFalse((root / "reports").exists())

    def test_llvm_warning_is_not_success(self):
        with patch.object(subprocess, "run", return_value=subprocess.CompletedProcess(
            ["tool"], 0, "{}", "warning: mismatched profile"
        )):
            with self.assertRaisesRegex(RuntimeError, "diagnostics"):
                coverage.run("tool")

    def test_second_scope_failure_does_not_publish_partial_xml(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            source = root / "MSAL/src/MSALPublicClientApplication.m"
            source.parent.mkdir(parents=True)
            source.write_text("int f(void) { return 1; }\n")
            output = root / "coverage"
            output.mkdir()
            scopes = []
            for name in sorted(coverage.TARGETS):
                directory = output / name
                (directory / "products").mkdir(parents=True)
                (directory / "profiles").mkdir()
                binary = directory / "products/MSAL"
                binary.write_bytes(b"binary")
                scopes.append({
                    "target": name, "architecture": "arm64", "binary_sha256": coverage.digest(binary),
                })
            (output / scopes[0]["target"] / "profiles/msal-signature-1.profraw").write_bytes(b"profile")
            coverage.save_json(output / "provenance.json", {
                "source_root": str(root), "source_sha256": {}, "scopes": scopes,
            })
            export = {"data": [{"files": [{
                "filename": str(source), "summary": {"lines": {"count": 1, "covered": 1}},
            }]}]}

            def tool(*args):
                if "-format=lcov" in args:
                    return f"SF:{source}\nDA:1,1\nend_of_record\n"
                return json.dumps(export) if "export" in args else ""

            with patch.object(coverage, "run", side_effect=tool):
                with patch.object(coverage, "profile_snapshot", return_value={}):
                    with self.assertRaisesRegex(ValueError, "Missing/empty"):
                        coverage.collect(root, output)
            self.assertTrue(list((output / "pending-reports").glob("*.cobertura.xml")))
            self.assertFalse((output / "reports").exists())

    def test_mapping_mismatch_and_wrong_source_root_fail(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            source = root / "MSAL/src/MSALPublicClientApplication.m"
            source.parent.mkdir(parents=True)
            source.write_text("int f(void) { return 1; }\n")
            item = {
                "filename": str(source), "segments": [[1, 1, 1, True, True, False]],
                "summary": {"lines": {"count": 2, "covered": 2}},
            }
            with self.assertRaisesRegex(ValueError, "totals"):
                coverage.production_files(
                    {"data": [{"files": [item]}]}, root, f"SF:{source}\nDA:1,1\nend_of_record\n"
                )
            item["filename"] = "/another-agent/MSAL/src/MSALPublicClientApplication.m"
            with self.assertRaisesRegex(ValueError, "different source root"):
                coverage.production_files({"data": [{"files": [item]}]}, root, "")


@unittest.skipUnless(os.uname().sysname == "Darwin", "Darwin continuous profiling acceptance probe")
class ContinuousProfileTests(unittest.TestCase):
    def test_dynamic_library_survives_kill_and_relaunch(self):
        """Tiny non-Xcode fixture: same toolchain/runtime, dynamic library and SIGKILL."""
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            source = root / "MSAL/src/MSALPublicClientApplication.m"
            source.parent.mkdir(parents=True)
            source.write_text(
                "int exercise(int input)\n"
                "{\n"
                "    if (input)\n"
                "    {\n"
                "        return 7;\n"
                "    }\n"
                "    return 3;\n"
                "}\n"
            )
            main = root / "main.c"
            main.write_text(
                "#include <stdio.h>\n#include <unistd.h>\n"
                "int exercise(int);\n"
                "int main(int argc, char **argv) {\n"
                "    printf(\"%d\\n\", exercise(argc > 1)); fflush(stdout);\n"
                "    pause(); return 0;\n}\n"
            )
            library = root / "libfixture.dylib"
            executable = root / "fixture"
            coverage.run(
                "xcrun", "clang", "-x", "c", "-dynamiclib", "-fprofile-instr-generate",
                "-fcoverage-mapping", str(source), "-o", str(library),
            )
            coverage.run(
                "xcrun", "clang", "-fprofile-instr-generate", "-fcoverage-mapping",
                str(main), str(library), "-o", str(executable),
            )
            for arguments, expected in [([], "3"), (["again"], "7")]:
                env = dict(os.environ, LLVM_PROFILE_FILE=str(root / "profile-%m-%p%c.profraw"))
                process = subprocess.Popen(
                    [str(executable), *arguments], env=env, stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE, text=True,
                )
                try:
                    self.assertEqual(process.stdout.readline().strip(), expected)
                finally:
                    process.kill()
                    _, stderr = process.communicate(timeout=10)
                self.assertEqual(stderr, "")
            profiles = sorted(root.glob("*.profraw"))
            self.assertGreaterEqual(len(profiles), 2)
            merged = root / "merged.profdata"
            coverage.run("xcrun", "llvm-profdata", "merge", "-sparse", *map(str, profiles), "-o", str(merged))
            export = json.loads(coverage.run(
                "xcrun", "llvm-cov", "export", str(library), f"-instr-profile={merged}",
            ))
            lcov = coverage.run(
                "xcrun", "llvm-cov", "export", str(library), "-format=lcov", f"-instr-profile={merged}",
            )
            files = coverage.production_files(export, root, lcov)
            counts = files["MSAL/src/MSALPublicClientApplication.m"]
            self.assertGreater(counts[5], 0)
            self.assertGreater(counts[7], 0)
            report = root / "report"
            report.mkdir()
            totals = coverage.reports(files, root, report, "msal-xcuitest-fixture")
            xml = ET.parse(report / "msal-xcuitest-fixture.cobertura.xml").getroot()
            self.assertEqual(int(xml.attrib["lines-valid"]), totals["lines_valid"])
            self.assertEqual(xml.find(".//class").attrib["filename"], "MSAL/src/MSALPublicClientApplication.m")
            detail = report / "msal-xcuitest-fixture/source-0.html"
            self.assertTrue(detail.is_file())
            self.assertIn('href="source-0.html"', (detail.parent / "index.html").read_text())
            output = root / "pilot"
            output.mkdir()
            scopes = []
            arch = coverage.run("xcrun", "lipo", "-archs", str(library)).strip()
            for name in coverage.TARGETS:
                directory = output / name
                (directory / "products").mkdir(parents=True)
                (directory / "profiles").mkdir()
                shutil.copy2(library, directory / "products/MSAL")
                for profile in profiles:
                    shutil.copy2(profile, directory / "profiles" / profile.name)
                scopes.append({
                    "target": name, "architecture": arch, "binary_sha256": coverage.digest(library),
                })
            coverage.save_json(output / "provenance.json", {
                "source_root": str(root), "source_sha256": {}, "scopes": scopes,
            })
            coverage.collect(root, output)
            self.assertEqual(len(list((output / "reports").glob("*.cobertura.xml"))), 2)
            self.assertEqual(json.loads((output / "provenance.json").read_text())["status"], "collected")


if __name__ == "__main__":
    unittest.main()
