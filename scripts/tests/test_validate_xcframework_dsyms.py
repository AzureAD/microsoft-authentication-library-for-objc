#------------------------------------------------------------------------------
#
# Copyright (c) Microsoft Corporation.
# All rights reserved.
#
# This code is licensed under the MIT License.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files(the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions :
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
#
#------------------------------------------------------------------------------

import contextlib
import importlib.util
import io
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SPEC = importlib.util.spec_from_file_location(
    "validate_xcframework_dsyms", Path(__file__).parents[1] / "validate_xcframework_dsyms.py"
)
validator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(validator)
UUID_ARM64 = "12345678-1234-1234-1234-123456789ABC"
UUID_X86 = "ABCDEF01-1234-1234-1234-123456789ABC"


class ValidateDsymsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="MSAL symbols ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "MSAL.xcframework"
        self.root.mkdir()
        self.libraries = []
        self.outputs = {}
        self.runner = patch.object(validator.subprocess, "run", side_effect=self.dwarfdump)
        self.runner.start()
        self.addCleanup(self.runner.stop)

    def dwarfdump(self, command, **kwargs):
        self.assertEqual(command[:3], ["xcrun", "dwarfdump", "--uuid"])
        self.assertTrue(kwargs["check"])
        return subprocess.CompletedProcess(command, 0, stdout=self.outputs[Path(command[3])])

    def add_slice(self, identifier, architectures=("arm64",), versioned=False):
        library = {
            "LibraryIdentifier": identifier,
            "LibraryPath": "MSAL.framework",
            "DebugSymbolsPath": "dSYMs",
            "SupportedArchitectures": list(architectures),
        }
        self.libraries.append(library)
        binary = self.root / identifier / "MSAL.framework/MSAL"
        symbols = self.root / identifier / "dSYMs/MSAL.framework.dSYM/Contents/Resources/DWARF/MSAL"
        for path in (binary, symbols):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.touch()
        if versioned:
            binary.unlink()
            actual = binary.parent / "Versions/A/MSAL"
            actual.parent.mkdir(parents=True)
            actual.touch()
            (binary.parent / "Versions/Current").symlink_to("A")
            binary.symlink_to("Versions/Current/MSAL")
        output = "".join(
            f"UUID: {UUID_ARM64 if arch == 'arm64' else UUID_X86} ({arch}) {binary}\n"
            for arch in architectures
        )
        self.outputs[binary] = output
        self.outputs[symbols] = output
        return library, binary, symbols

    def validate(self, count=None):
        with (self.root / "Info.plist").open("wb") as metadata:
            plistlib.dump({"AvailableLibraries": self.libraries}, metadata)
        with contextlib.redirect_stdout(io.StringIO()):
            validator.validate(self.root, len(self.libraries) if count is None else count)

    def test_existing_platform_sets_and_versioned_macos(self):
        self.add_slice("ios-arm64")
        self.add_slice("ios-arm64_x86_64-simulator", ("arm64", "x86_64"))
        self.add_slice("macos-arm64_x86_64", ("arm64", "x86_64"), versioned=True)
        self.validate(3)
        self.add_slice("xros-arm64")
        self.add_slice("xros-arm64-simulator")
        self.validate(5)

    def test_missing_symbol_metadata(self):
        library, _, _ = self.add_slice("ios-arm64")
        del library["DebugSymbolsPath"]
        with self.assertRaisesRegex(ValueError, "Missing DebugSymbolsPath"):
            self.validate()

    def test_missing_binaries(self):
        _, binary, symbols = self.add_slice("ios-arm64")
        for path in (binary, symbols):
            with self.subTest(path=path):
                path.unlink()
                with self.assertRaisesRegex(ValueError, "Missing binary"):
                    self.validate()
                path.touch()

    def test_uuid_and_architecture_mismatches(self):
        library, binary, symbols = self.add_slice("ios-arm64_x86_64-simulator", ("arm64", "x86_64"))
        for output in (
            self.outputs[binary].replace(UUID_ARM64, UUID_X86),
            f"UUID: {UUID_ARM64} (arm64) {symbols}\n",
            self.outputs[binary] + f"UUID: {UUID_ARM64} (arm64e) {symbols}\n",
        ):
            with self.subTest(output=output):
                self.outputs[symbols] = output
                with self.assertRaisesRegex(ValueError, "UUID/architecture mismatch"):
                    self.validate()
        self.outputs[symbols] = self.outputs[binary]
        library["SupportedArchitectures"] = ["arm64"]
        with self.assertRaisesRegex(ValueError, "UUID/architecture mismatch"):
            self.validate()

    def test_invalid_dwarfdump_output(self):
        _, binary, _ = self.add_slice("ios-arm64")
        output = self.outputs[binary]
        for invalid in ("", "not a UUID\n", output + output):
            with self.subTest(output=invalid):
                self.outputs[binary] = invalid
                with self.assertRaises(ValueError):
                    self.validate()

    def test_uuid_case_is_not_significant(self):
        _, _, symbols = self.add_slice("ios-arm64")
        self.outputs[symbols] = self.outputs[symbols].replace(UUID_ARM64, UUID_ARM64.lower())
        self.validate()

    def test_slice_count_and_duplicates(self):
        library, _, _ = self.add_slice("ios-arm64")
        with self.assertRaisesRegex(ValueError, "Expected 3 slices"):
            self.validate(3)
        self.libraries.append(library)
        with self.assertRaisesRegex(ValueError, "Duplicate slice"):
            self.validate(2)

    def test_invalid_metadata_paths_and_architectures(self):
        library, _, _ = self.add_slice("ios-arm64")
        for key, value in (
            ("LibraryIdentifier", "../outside"),
            ("DebugSymbolsPath", "/outside"),
            ("DebugSymbolsPath", ""),
            ("LibraryPath", "Other.framework"),
            ("SupportedArchitectures", []),
            ("SupportedArchitectures", ["arm64", "arm64"]),
        ):
            with self.subTest(key=key, value=value):
                original = library[key]
                library[key] = value
                with self.assertRaises(ValueError):
                    self.validate()
                library[key] = original

    def test_cli_failure_is_nonzero_and_actionable(self):
        self.add_slice("ios-arm64")
        self.validate()
        for error in (
            ValueError("missing symbols"),
            FileNotFoundError("missing dwarfdump"),
            subprocess.CalledProcessError(1, "dwarfdump", stderr="invalid binary"),
        ):
            with self.subTest(error=error), patch.object(validator, "validate", side_effect=error):
                with patch("sys.argv", ["validator", str(self.root), "--expected-slices", "1"]):
                    with contextlib.redirect_stderr(io.StringIO()) as stderr:
                        self.assertEqual(validator.main(), 1)
                    self.assertIn("dSYM validation failed", stderr.getvalue())
                    self.assertIn(str(error), stderr.getvalue())

    def test_cli_success(self):
        self.add_slice("ios-arm64")
        self.validate()
        with patch("sys.argv", ["validator", str(self.root), "--expected-slices", "1"]):
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(validator.main(), 0)


class PackagingArgumentsTests(unittest.TestCase):
    def test_sh_arguments_preserve_spaces_and_platform_selection(self):
        script = (Path(__file__).parents[2] / "spm-integration-test.sh").read_text()
        archive_commands = [
            line for line in script.splitlines()
            if line.lstrip().startswith("xcodebuild ") and " archive " in line
        ]
        self.assertEqual(len(archive_commands), 5)
        for command in archive_commands:
            self.assertIn("DEBUG_INFORMATION_FORMAT=dwarf-with-dsym", command)
        start = script.index("# -debug-symbols requires absolute paths")
        end = script.index('xcodebuild -create-xcframework "$@"')
        # Exercise only argument assembly, never archives or the temporary-branch publisher.
        assembly = re.sub(r"^  xcodebuild .*$", "  :", script[start:end], flags=re.MULTILINE)
        with tempfile.TemporaryDirectory(prefix="MSAL packaging ") as directory:
            for visionos in (False, True):
                with self.subTest(visionos=visionos):
                    result = subprocess.run(
                        ["sh", "-c", f"INCLUDE_VISIONOS={str(visionos).lower()}\n"
                         + assembly + '\nprintf "%s\\n" ARGS "$EXPECTED_SLICES" "$@"'],
                        cwd=directory, check=True, capture_output=True, text=True
                    )
                    lines = result.stdout.splitlines()
                    args = lines[lines.index("ARGS") + 1:]
                    archives = ["iOSSimulator", "iOS", "macOS"]
                    if visionos:
                        archives += ["visionOSSimulator", "visionOS"]
                    expected = [str(len(archives))]
                    for archive in archives:
                        root = Path(directory).resolve() / "archive" / f"{archive}.xcarchive"
                        expected += [
                            "-framework", str(root / "Products/Library/Frameworks/MSAL.framework"),
                            "-debug-symbols", str(root / "dSYMs/MSAL.framework.dSYM")
                        ]
                    self.assertEqual(args, expected)


if __name__ == "__main__":
    unittest.main()
