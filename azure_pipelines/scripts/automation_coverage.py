# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

"""Bounded simulator XCUITest coverage; never reads or retains automation credentials."""

import argparse
import hashlib
import html
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET


TARGETS = {"InteractiveiOSTests", "MultiAppiOSTests"}
SCHEME = "MSAL Test Automation (iOS)"


def run(*args):
    result = subprocess.run(args, capture_output=True, text=True, check=True)
    # LLVM reports profile/mapping mismatches as warnings with exit code zero.
    if result.stderr.strip():
        raise RuntimeError(f"{args[0]} reported diagnostics: {result.stderr.strip()}")
    return result.stdout


def save_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def test_targets(document):
    if "TestConfigurations" in document:
        return [
            target
            for config in document["TestConfigurations"]
            if config.get("IsEnabled", True)
            for target in config["TestTargets"]
            if target.get("IsEnabled", True)
        ]
    return [
        dict(value, BlueprintName=name)
        for name, value in document.items()
        if name != "__xctestrun_metadata__" and isinstance(value, dict)
    ]


def app_path(target, testroot):
    value = target["UITargetAppPath"].replace("__TESTROOT__", str(testroot))
    path = Path(value).resolve()
    if not path.is_relative_to(testroot.resolve()) or not path.is_dir():
        raise ValueError("UITargetAppPath is not a local build product")
    return path


def prepare(root, output, scheme, destination):
    if scheme != SCHEME or not destination.startswith("platform=iOS Simulator,"):
        raise ValueError("The pilot supports only the existing iOS simulator XCUITest scheme")
    products = root / "build/Build/Products"
    candidates = sorted(products.glob(f"{scheme}*.xctestrun"))
    if len(candidates) != 1:
        raise ValueError("Coverage requires exactly one matching xctestrun; refusing ambiguous products")
    xctestrun = candidates[0]
    document = plistlib.loads(xctestrun.read_bytes())
    targets = test_targets(document)
    if {target["BlueprintName"] for target in targets} != TARGETS or len(targets) != 2:
        raise ValueError("Unexpected XCUITest selection; coverage pilot must be reviewed")
    if any(not target.get("IsUITestBundle", "UITargetAppPath" in target) for target in targets):
        raise ValueError("Coverage scope contains a non-XCUITest bundle")
    if any(output.iterdir()):
        raise ValueError("Coverage output must be empty to avoid mixing attempts")

    scopes = []
    for target in targets:
        name = target["BlueprintName"]
        app = app_path(target, products)
        binary = app / "Frameworks/MSAL.framework/MSAL"
        if not binary.is_file():
            raise ValueError("The exercised app must embed the locally built MSAL framework")
        archs = run("xcrun", "lipo", "-archs", str(binary)).split()
        if len(archs) != 1:
            raise ValueError("Pilot requires a single-architecture MSAL product; refusing to guess")
        scope = output / name
        (scope / "profiles").mkdir(parents=True)
        (scope / "products").mkdir()
        shutil.copy2(binary, scope / "products/MSAL")
        info = plistlib.loads((app / "Info.plist").read_bytes())
        executable = app / info["CFBundleExecutable"]
        if run("xcrun", "lipo", "-archs", str(executable)).split() != archs:
            raise ValueError("App and embedded MSAL architectures differ")
        shutil.copy2(executable, scope / "products/automation-app")
        # PID separates relaunches; continuous mmap preserves counters on forced termination.
        target.setdefault("UITargetAppEnvironmentVariables", {})["LLVM_PROFILE_FILE"] = str(
            scope / "profiles/msal-%m-%p%c.profraw"
        )
        scopes.append({
            "target": name,
            "architecture": archs[0],
            "binary_sha256": digest(binary),
            "app_sha256": digest(executable),
            "only_tests": target.get("OnlyTestIdentifiers", []),
            "skipped_tests": target.get("SkipTestIdentifiers", []),
        })
    # Legacy xctestrun entries are copies; update only the environment in the original entries.
    if "TestConfigurations" not in document:
        for target in targets:
            document[target["BlueprintName"]]["UITargetAppEnvironmentVariables"] = (
                target["UITargetAppEnvironmentVariables"]
            )
    provenance = {
        "status": "prepared",
        "source_commit": run("git", "-C", str(root), "rev-parse", "HEAD").strip(),
        "build_id": os.environ.get("COVERAGE_BUILD_ID"),
        "stage_attempt": os.environ.get("COVERAGE_STAGE_ATTEMPT"),
        "job_attempt": os.environ.get("COVERAGE_JOB_ATTEMPT"),
        "scheme": scheme,
        "destination": destination,
        "aggregation": "all test iterations, including retries; NOT first-pass coverage",
        "retry_tests": os.environ.get("COVERAGE_RETRY_TESTS"),
        "source_root": str(root),
        "llvm_version": run("xcrun", "llvm-cov", "--version").strip(),
        "source_sha256": {
            path.relative_to(root).as_posix(): digest(path)
            for path in sorted((root / "MSAL/src").rglob("*")) if path.is_file()
        },
        "scopes": scopes,
    }
    save_json(output / "provenance.json", provenance)
    xctestrun.write_bytes(plistlib.dumps(document))


def lcov_lines(text):
    """Use LLVM's native line mapping instead of approximating JSON segment ranges."""
    result = {}
    current = None
    for line in text.splitlines():
        if line.startswith("SF:"):
            current = str(Path(line[3:]).resolve())
            if current in result:
                raise ValueError("Duplicate LCOV source record")
            result[current] = {}
        elif line.startswith("DA:"):
            if current is None:
                raise ValueError("LCOV line without source")
            number, count = map(int, line[3:].split(",")[:2])
            if number < 1 or count < 0 or number in result[current]:
                raise ValueError("Invalid/duplicate LCOV line")
            result[current][number] = count
        elif line == "end_of_record":
            current = None
    return result


def production_files(export, root, lcov):
    mapped_lines = lcov_lines(lcov)
    result = {}
    for data in export["data"]:
        for item in data["files"]:
            source = Path(item["filename"]).resolve()
            if not source.is_relative_to(root / "MSAL/src"):
                if "/MSAL/src/" in str(source):
                    raise ValueError("Production source mapping belongs to a different source root")
                continue
            if not source.is_file():
                raise ValueError("Production source mapping cannot be resolved on this agent")
            name = source.relative_to(root).as_posix()
            counts = mapped_lines.get(str(source), {})
            summary = item["summary"]["lines"]
            if len(counts) != summary["count"] or sum(v > 0 for v in counts.values()) != summary["covered"]:
                raise ValueError(f"Line mapping disagrees with LLVM totals for {name}")
            if counts and max(counts) > len(source.read_text().splitlines()):
                raise ValueError("Mapped coverage line exceeds production source length")
            if name in result:
                raise ValueError("Duplicate production source mapping")
            if counts:
                result[name] = counts
    if not result or not any(
        any(count > 0 for count in counts.values())
        for name, counts in result.items()
        if name.endswith("/MSALPublicClientApplication.m")
    ):
        raise ValueError("No executed MSALPublicClientApplication mapping; collection is incomplete")
    return result


def reports(files, root, output, basename):
    valid = sum(len(counts) for counts in files.values())
    covered = sum(value > 0 for counts in files.values() for value in counts.values())
    coverage = ET.Element("coverage", {
        "lines-valid": str(valid), "lines-covered": str(covered),
        "line-rate": str(covered / valid), "branch-rate": "0", "version": "1",
    })
    ET.SubElement(ET.SubElement(coverage, "sources"), "source").text = str(root)
    package = ET.SubElement(ET.SubElement(coverage, "packages"), "package", {
        "name": basename, "line-rate": str(covered / valid), "branch-rate": "0",
    })
    classes = ET.SubElement(package, "classes")
    html_root = output / basename
    html_root.mkdir()
    links = []
    for index, (name, counts) in enumerate(sorted(files.items())):
        hits = sum(value > 0 for value in counts.values())
        item = ET.SubElement(classes, "class", {
            "name": name, "filename": name, "line-rate": str(hits / len(counts)),
            "branch-rate": "0",
        })
        ET.SubElement(item, "methods")
        lines = ET.SubElement(item, "lines")
        for number, count in sorted(counts.items()):
            ET.SubElement(lines, "line", {"number": str(number), "hits": str(count)})
        detail = f"source-{index}.html"
        rows = []
        for number, text in enumerate((root / name).read_text().splitlines(), 1):
            count = counts.get(number)
            color = "#dfd" if count and count > 0 else "#fdd" if count == 0 else "#fff"
            rows.append(
                f'<tr id="L{number}" style="background:{color}"><td>{number}</td>'
                f'<td>{count if count is not None else ""}</td><td><pre>{html.escape(text)}</pre></td></tr>'
            )
        (html_root / detail).write_text(
            f"<!doctype html><meta charset='utf-8'><title>{html.escape(name)}</title>"
            f"<h1>{html.escape(name)}</h1><table>{''.join(rows)}</table>"
        )
        links.append(f'<li><a href="{detail}">{html.escape(name)}</a>: {hits}/{len(counts)}</li>')
    (html_root / "index.html").write_text(
        f"<!doctype html><meta charset='utf-8'><title>{basename}</title><h1>{basename}</h1>"
        f"<p>All retry iterations; not first-pass coverage. Lines: {covered}/{valid}.</p>"
        f"<ul>{''.join(links)}</ul>"
    )
    ET.ElementTree(coverage).write(output / f"{basename}.cobertura.xml", encoding="utf-8", xml_declaration=True)
    return {"lines_valid": valid, "lines_covered": covered}


def profile_snapshot(profiles):
    hashes = {}
    for path in profiles:
        pid = int(path.stem.rsplit("-", 1)[1])
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            hashes[path.name] = digest(path)
        else:
            raise ValueError("A profiled app process is still alive; counters are not a final snapshot")
    return hashes


def collect(root, output):
    provenance = json.loads((output / "provenance.json").read_text())
    if provenance["source_root"] != str(root):
        raise ValueError("Collection must use the original build source root")
    for name, expected in provenance["source_sha256"].items():
        if digest(root / name) != expected:
            raise ValueError("Production sources changed after coverage preparation")
    pending = output / "pending-reports"
    pending.mkdir()
    for scope in provenance["scopes"]:
        directory = output / scope["target"]
        binary = directory / "products/MSAL"
        if digest(binary) != scope["binary_sha256"]:
            raise ValueError("Retained MSAL binary changed after preparation")
        profiles = sorted((directory / "profiles").glob("*.profraw"))
        if not profiles or any(path.stat().st_size == 0 for path in profiles):
            raise ValueError(f"Missing/empty app profiles for {scope['target']}; not zero coverage")
        snapshot = profile_snapshot(profiles)
        profdata = directory / "merged.profdata"
        run("xcrun", "llvm-profdata", "merge", "-sparse", *map(str, profiles), "-o", str(profdata))
        export = json.loads(run(
            "xcrun", "llvm-cov", "export", str(binary),
            f"-instr-profile={profdata}", f"-arch={scope['architecture']}",
        ))
        save_json(directory / "llvm-export.json", export)
        lcov = run(
            "xcrun", "llvm-cov", "export", str(binary), "-format=lcov",
            f"-instr-profile={profdata}", f"-arch={scope['architecture']}",
        )
        (directory / "coverage.lcov").write_text(lcov)
        files = production_files(export, root, lcov)
        if snapshot != profile_snapshot(profiles):
            raise ValueError("Raw profiles changed during collection")
        basename = f"msal-xcuitest-{scope['target']}"
        scope["totals"] = reports(files, root, pending, basename)
        scope["profiles"] = [
            {"name": path.name, "sha256": digest(path)} for path in profiles
        ]
        scope["source_files"] = [
            {"path": name, "sha256": digest(root / name)} for name in sorted(files)
        ]
    # Publish no native XML unless every selected target collected valid production coverage.
    pending.rename(output / "reports")
    provenance["status"] = "collected"
    save_json(output / "provenance.json", provenance)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["prepare", "collect"])
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--scheme", default=SCHEME)
    parser.add_argument("--destination", default="")
    args = parser.parse_args()
    root, output = args.root.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    try:
        if args.action == "prepare":
            prepare(root, output, args.scheme, args.destination)
        else:
            print("##vso[task.setvariable variable=msalUiCoverageReady]false", flush=True)
            collect(root, output)
            print("##vso[task.setvariable variable=msalUiCoverageReady]true")
    except (ValueError, KeyError, OSError, RuntimeError, subprocess.CalledProcessError) as error:
        # Do not include command stdout: test configuration and logs may contain credentials.
        message = str(error) if not isinstance(error, subprocess.CalledProcessError) else (
            f"Coverage tool failed with exit code {error.returncode}"
        )
        save_json(output / "collection-error.json", {"status": "incomplete", "error": message})
        print(f"##vso[task.logissue type=error]XCUITest coverage incomplete: {message}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
