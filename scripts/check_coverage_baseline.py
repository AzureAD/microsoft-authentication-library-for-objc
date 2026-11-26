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

"""Warn on same-run Cobertura scheme totals below a provisional minimum."""

import argparse
from decimal import Decimal, InvalidOperation
from fractions import Fraction
from fnmatch import fnmatchcase
from pathlib import Path
import re
import xml.etree.ElementTree as ET


class CoverageUnavailable(ValueError):
    """The report cannot provide usable root line counts."""


def minimum_percent(value):
    try:
        number = Decimal(value)
    except InvalidOperation as error:
        raise argparse.ArgumentTypeError("minimum must be a percentage in [0, 100]") from error
    if not number.is_finite() or not 0 <= number <= 100:
        raise argparse.ArgumentTypeError("minimum must be a percentage in [0, 100]")
    return number


def read_counts(pattern):
    path = Path(pattern)
    if any(character in str(path.parent) for character in "*?[]"):
        raise ValueError("report directory must be literal; wildcards are supported only in the filename")
    try:
        reports = [entry for entry in path.parent.iterdir() if fnmatchcase(entry.name, path.name)]
    except FileNotFoundError as error:
        raise CoverageUnavailable("report directory missing") from error
    if len(reports) != 1:
        raise CoverageUnavailable(f"expected exactly one report, found {len(reports)}")
    try:
        root = ET.parse(reports[0]).getroot()
    except FileNotFoundError as error:
        raise CoverageUnavailable("report missing") from error
    except ET.ParseError as error:
        raise CoverageUnavailable("malformed XML") from error
    if root.tag != "coverage":
        raise CoverageUnavailable("expected a Cobertura coverage root")
    values = [root.get("lines-covered", ""), root.get("lines-valid", "")]
    if not all(re.fullmatch(r"[0-9]+", value) for value in values):
        raise CoverageUnavailable("missing or non-integer root line counts")
    covered, valid = map(int, values)
    if valid == 0 or covered > valid:
        raise CoverageUnavailable("root counts require 0 <= covered <= valid and valid > 0")
    return covered, valid


def log_data(message):
    return message.replace("%", "%AZP25").replace("\r", "%0D").replace("\n", "%0A")


def warn(message):
    print(f"##vso[task.logissue type=warning]{log_data(message)}")
    print("##vso[task.complete result=SucceededWithIssues;]Coverage baseline warning.")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", required=True, help="Quoted glob matching exactly one same-run XML")
    parser.add_argument("--suite", choices=("MSAL (iOS Framework)", "MSAL (Mac Framework)"), required=True)
    parser.add_argument("--minimum", type=minimum_percent, required=True)
    parser.add_argument("--revision", required=True)
    args = parser.parse_args(argv)
    context = f"{args.suite}: minimum={args.minimum}%, revision={args.revision}"
    try:
        covered, valid = read_counts(args.report)
    except CoverageUnavailable as error:
        warn(f"{context}; covered/valid=unavailable, actual=unavailable; "
             f"coverage unavailable/incomplete ({error})")
        return 0

    actual = Decimal(covered) * 100 / Decimal(valid)
    summary = f"{context}; covered/valid={covered}/{valid}, actual={actual:.6f}%"
    # Compare exact counts, never the rounded line-rate attribute or display.
    if Fraction(covered * 100, valid) < Fraction(args.minimum):
        warn(f"{summary}; below minimum")
    else:
        print(log_data(f"{summary}; at or above minimum"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
