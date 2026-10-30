#!/usr/bin/env python3
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

"""Require packaged MSAL dSYMs with matching UUIDs for every XCFramework slice."""

import argparse
from pathlib import Path
import plistlib
import re
import subprocess
import sys


UUID_LINE = re.compile(
    r"UUID: ([0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}) \(([^)]+)\) .+"
)


def binary_uuids(binary):
    if not binary.is_file():
        raise ValueError(f"Missing binary: {binary}")
    result = subprocess.run(
        ["xcrun", "dwarfdump", "--uuid", str(binary)],
        check=True, capture_output=True, text=True
    )
    uuids = {}
    for line in result.stdout.splitlines():
        match = UUID_LINE.fullmatch(line.strip())
        if not match or match[2] in uuids:
            raise ValueError(f"Invalid or duplicate UUID entry for {binary}: {line}")
        uuids[match[2]] = match[1].upper()
    if not uuids:
        raise ValueError(f"No UUIDs found in {binary}")
    return uuids


def relative_path(metadata, key):
    value = metadata.get(key)
    if not isinstance(value, str) or not value:
        raise ValueError(f"Missing {key} in XCFramework metadata")
    path = Path(value)
    if path.is_absolute() or ".." in path.parts:
        raise ValueError(f"{key} must be relative to its XCFramework directory: {value}")
    return path


def validate(xcframework, expected_slices):
    with (xcframework / "Info.plist").open("rb") as metadata:
        info = plistlib.load(metadata)
    libraries = info.get("AvailableLibraries") if isinstance(info, dict) else None
    if not isinstance(libraries, list) or not libraries or len(libraries) != expected_slices:
        raise ValueError(f"Expected {expected_slices} slices in {xcframework}/Info.plist")
    identifiers = set()
    for library in libraries:
        if not isinstance(library, dict):
            raise ValueError("Invalid AvailableLibraries entry")
        identifier = relative_path(library, "LibraryIdentifier")
        if identifier in identifiers:
            raise ValueError(f"Duplicate slice: {identifier}")
        identifiers.add(identifier)
        slice_path = xcframework / identifier
        framework = relative_path(library, "LibraryPath")
        symbols = relative_path(library, "DebugSymbolsPath")
        if framework != Path("MSAL.framework"):
            raise ValueError(f"Unexpected framework in {identifier}: {framework}")
        architectures = library.get("SupportedArchitectures")
        if (not isinstance(architectures, list) or not architectures
                or any(not isinstance(arch, str) or not arch for arch in architectures)
                or len(set(architectures)) != len(architectures)):
            raise ValueError(f"Invalid SupportedArchitectures for {identifier}")
        framework_uuids = binary_uuids(slice_path / framework / "MSAL")
        dsym_uuids = binary_uuids(
            slice_path / symbols / "MSAL.framework.dSYM/Contents/Resources/DWARF/MSAL"
        )
        if set(framework_uuids) != set(architectures) or framework_uuids != dsym_uuids:
            raise ValueError(
                f"dSYM UUID/architecture mismatch for {identifier}: "
                f"metadata={architectures}, framework={framework_uuids}, dSYM={dsym_uuids}"
            )
        print(f"Validated dSYM UUIDs for {identifier}: {framework_uuids}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("xcframework", type=Path)
    parser.add_argument("--expected-slices", type=int, required=True)
    args = parser.parse_args()
    try:
        validate(args.xcframework, args.expected_slices)
    except subprocess.CalledProcessError as error:
        print(f"dSYM validation failed: {error}: {error.stderr}", file=sys.stderr)
        return 1
    except (OSError, ValueError, plistlib.InvalidFileException) as error:
        print(f"dSYM validation failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
