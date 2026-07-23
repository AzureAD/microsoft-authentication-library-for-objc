#!/usr/bin/env python3

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

import subprocess
import traceback
import sys
import re
import os
import json
import xml.etree.ElementTree as ET
import argparse
import platform
import shutil
import device_guids

from timeit import default_timer as timer

script_start_time = timer()

def select_formatter(enabled) :
	if not enabled :
		return None
	if shutil.which("xcbeautify") :
		return "xcbeautify"
	if shutil.which("xcpretty") :
		print("Warning: xcbeautify not found; falling back to xcpretty")
		return "xcpretty"
	print("Warning: xcbeautify/xcpretty not found; using raw xcodebuild output")
	return None

# Simulator device/OS can be overridden via environment variables so the values
# can be centralized in the shared (common) pipeline configuration. Defaults are
# used when the environment variables are not set.
ios_sim_device_type = os.environ.get("IOS_SIM_DEVICE", "iPhone 17")
ios_sim_os = os.environ.get("IOS_SIM_OS", "26.1")
ios_sim_device_exact_name = ios_sim_device_type + " Simulator \\(" + ios_sim_os + "\\)"
ios_sim_dest = "-destination 'platform=iOS Simulator,name=" + ios_sim_device_type + ",OS=" + ios_sim_os + "'"
ios_sim_flags = "-sdk iphonesimulator CODE_SIGN_IDENTITY=\"\" CODE_SIGNING_REQUIRED=NO"

vision_sim_device_exact_name = os.environ.get("VISION_SIM_DEVICE", "Apple Vision Pro")
vision_sim_os = os.environ.get("VISION_SIM_OS", "1.2")
vision_sim_dest = "-destination 'platform=visionOS Simulator,name=" + vision_sim_device_exact_name + ",OS=" + vision_sim_os + "'"
vision_sim_flags = "-sdk xrsimulator CODE_SIGN_IDENTITY=\"\" CODE_SIGNING_REQUIRED=NO"

default_workspace = "MSAL.xcworkspace"
default_config = "Debug"

use_formatter = True
show_build_settings = False

class ColorValues:
	HDR = '\033[1m'
	OK = '\033[32m\033[1m'
	FAIL = '\033[31m\033[1m'
	WARN = '\033[33m\033[1m'
	SKIP = '\033[96m\033[1m'
	END = '\033[0m'

target_specifiers = [
	{
		"name" : "iOS Framework",
		"scheme" : "MSAL (iOS Framework)",
		"operations" : [ "build", "test" ],
		"min_warn_codecov" : 70.0,
		"platform" : "iOS",
        "target" : "iosFramework"
	},
	{
		"name" : "iOS Test App",
		"scheme" : "MSAL Test App (iOS)",
		"operations" : [ "build" ],
		"platform" : "iOS",
        "target" : "iosTestApp"

	},
	{
		"name" : "Sample iOS App",
		"scheme" : "SampleAppiOS",
		"workspace" : "Samples/ios/SampleApp.xcworkspace",
		"operations" : [ "build" ],
		"platform" : "iOS",
        "target" : "sampleIosApp"
	},
    {
        "name" : "Sample iOS App-iOS",
        "scheme" : "SampleAppiOS-Swift",
        "workspace" : "Samples/ios/SampleApp.xcworkspace",
        "operations" : [ "build" ],
        "platform" : "iOS",
        "target" : "sampleIosAppSwift"
    },
	{
		"name" : "Mac Framework",
		"scheme" : "MSAL (Mac Framework)",
		"operations" : [ "build", "test", "codecov" ],
		"min_warn_codecov" : 70.0,
		"platform" : "Mac",
        "target" : "macFramework"
	},
    {
        "name" : "Vision Framework",
        "scheme" : "MSAL (iOS Framework)",
        "operations" : [ "build", "test" ],
        "min_warn_codecov" : 70.0,
        "platform" : "visionOS",
        "target" : "visionOSFramework"
    },
]

def print_operation_start(name, operation) :
	print(ColorValues.HDR + "Beginning " + name + " [" + operation + "]" + ColorValues.END)
	print("##[group]" + (name + "_" + operation).replace(" ", "_"))

def print_operation_end(name, operation, exit_code, start_time) :
	print("##[endgroup]" + (name + "_" + operation).replace(" ", "_"))
	
	end_time = timer()

	if (exit_code == 0) :
		print(ColorValues.OK + name + " [" + operation + "] Succeeded" + ColorValues.END + " (" + "{0:.2f}".format(end_time - start_time) + " seconds)")
	else :
		print(ColorValues.FAIL + name + " [" + operation + "] Failed" + ColorValues.END + " (" + "{0:.2f}".format(end_time - start_time) + " seconds)")

class BuildTarget:
	def __init__(self, target):
		self.name = target["name"]
		self.project = target.get("project")
		self.workspace = target.get("workspace")
		if (self.workspace == None and self.project == None) :
			self.workspace = default_workspace
		self.scheme = target["scheme"]
		self.dependencies = target.get("dependencies")
		self.device_guid = None
		self.operations = target["operations"]
		self.platform = target["platform"]
		self.build_settings = None
		self.min_codecov = target.get("min_codecov")
		self.min_warn_codecov = target.get("min_warn_codecov")
		self.use_sonarcube = target.get("use_sonarcube")
		self.coverage = None
		self.failed = False
		self.skipped = False
		self.start_time = None
		self.end_time = None
		self.linter = target.get("linter", "swiftlint")
		self.directory = target.get("directory", ".")
	
	def xcodebuild_command(self, operation, formatter) :
		"""
		Generate and return an xcodebuild command string based on the ivars and operation provided.
		"""
		command = "xcodebuild "
		
		if (operation != None) :
		# This lets us short circuit the build step in the test operation and cuts time off the overall build
			xcb_operation = operation
			if (operation == "build" and "test" in self.operations) :
				xcb_operation = "build-for-testing"
			elif (operation == "test" and "build" in self.operations) :
				xcb_operation = "test-without-building"
			command += xcb_operation + " "
		
		if (self.project != None) :
			command += " -project " + self.project
		else :
			command += " -workspace " + self.workspace
		
		command += " -scheme \"" + self.scheme + "\" -configuration " + default_config
		
		# The shallow analyzer is buggy. Stupidly buggy, causing random failures that didn't fail the build on things like
		# headers not being found. If Apple can't make this reliable then we should short circuit it out of our build
		if (operation == "build") :
			command += " RUN_CLANG_STATIC_ANALYZER=NO"
		
		if (operation != None and "codecov" in self.operations and xcb_operation in ["test", "build-for-testing", "test-without-building"]) :
			command += " -enableCodeCoverage YES"

		if (self.platform == "iOS") :
			command += " " + ios_sim_flags + " " + ios_sim_dest

		if (self.platform == "visionOS") :
			command += " " + vision_sim_flags + " " + vision_sim_dest
		
		if (operation == "test") :
			command += " -resultBundlePath './build/reports/" + self.name + ".xcresult'"
		
		if (formatter == "xcbeautify") :
			command += " | xcbeautify"
			if in_ado_ci :
				command += " --renderer azure-devops-pipelines"
			if (operation == "test") :
				command += " --report junit --report-path ./build/reports --junit-report-filename '" + self.name + ".xml'"
		elif (formatter == "xcpretty") :
			command += " | xcpretty"
			if (operation == "test") :
				command += " --report junit --output ./build/reports/'" + self.name + ".xml'"
		
		return command
	
	def get_build_settings(self) :
		"""
		Retrieve the build settings from xcodebuild and return thm in a dictionary
		"""
		
		if (self.build_settings != None) :
			return self.build_settings
		
		print("Retrieving Build Settings for " + self.name)
		if (show_build_settings) :
			print("##[group]" + (self.name + "_settings").replace(" ", "_"))
				
		command = self.xcodebuild_command(None, False)
		command += " -showBuildSettings"
		print(command)
		
		start = timer()
        
		settings_blob = subprocess.check_output(command, shell=True)
		if (show_build_settings) :
			print(settings_blob)
			print("##[endgroup]" + (self.name + "_settings").replace(" ", "_"))
		
		settings_blob = settings_blob.decode("utf-8")
		settings_blob = settings_blob.split("\n")
        
		settings = {}
		
		for line in settings_blob :
			split_line = line.split(" = ")
			if (len(split_line) < 2) :
				continue
			key = split_line[0].strip()
			value = split_line[1].strip()
			
			settings[key] = value
		
		self.build_settings = settings
		
		end = timer()
		
		print("Retrieved Build Settings (" + "{0:.2f}".format(end - start) + " sec)")
		
		return settings
		
	def print_coverage(self, printname) :
		"""
		Print a summary of the code coverage results with the proper coloring and
		return -1 if the coverage is below the minimum required.
		"""
		if (self.coverage == None) :
			return 0;
			
		printed = False
		
		if (self.min_warn_codecov != None and self.coverage < self.min_warn_codecov) :
			sys.stdout.write(ColorValues.WARN)
			if (printname) :
				sys.stdout.write(self.name + ": ")
			sys.stdout.write(str(self.coverage) + "% coverage is below the recommended minimum requirement: " + str(self.min_warn_codecov) + "%" + ColorValues.END + "\n")
			printed = True
				
		if (self.min_codecov != None and self.coverage < self.min_codecov) :
			sys.stdout.write(ColorValues.FAIL)
			if (printname) :
				sys.stdout.write(self.name + ": ")
			sys.stdout.write(str(self.coverage) + "% coverage is below the minimum requirement: " + str(self.min_codecov) + "%" + ColorValues.END + "\n")
			return -1
		
		if (not printed) :
			sys.stdout.write(ColorValues.OK)
			if (printname) :
				sys.stdout.write(self.name + ": ")
			sys.stdout.write(str(self.coverage) + "%" + ColorValues.END + "\n")
			
		return 0
	
	def get_device_guid(self) :
		if (self.platform == "iOS") :
			return device_guids.get_ios(ios_sim_device_exact_name)
   
		if (self.platform == "visionOS") :
			return device_guids.get_ios(vision_sim_device_exact_name)
		
		if (self.platform == "Mac") :
			return device_guids.get_mac().decode(sys.stdout.encoding)
		
		raise Exception("Unsupported platform: \"" + self.platform + "\", valid platforms are \"iOS\", \"visionOS\", and \"Mac\"")

	def do_lint(self) :
		if (self.linter != "swiftlint") :
			sys.stdout.write("Unknown linter '" + self.linter + "'\n")
			return

		command = "swiftlint lint --strict " + self.directory

		result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True )

		sys.stdout.write(result.stdout.decode(sys.stdout.encoding))

		return result.returncode
	
	def do_codecov(self) :
		"""
		Print a code coverage report using llvm_cov, retrieve the coverage result and
		print out an error if it is below the minimum requirement
		"""
		build_settings = self.get_build_settings();
		build_dir = build_settings["BUILD_DIR"]
		derived_dir = os.path.normpath(build_dir + "/..")

		# Xcode writes Coverage.profdata under ProfileData/<TestDevice UUID>/. That
		# UUID does not match the host hardware UUID on Apple Silicon, so prefer
		# discovering the folder directly. Fall back to the legacy device-GUID path.
		profile_data_dir = derived_dir + "/ProfileData"
		profile_data_path = None
		newest_mtime = None
		if os.path.isdir(profile_data_dir) :
			for entry in os.listdir(profile_data_dir) :
				candidate = os.path.join(profile_data_dir, entry, "Coverage.profdata")
				if os.path.isfile(candidate) :
					mtime = os.path.getmtime(candidate)
					if newest_mtime is None or mtime > newest_mtime :
						newest_mtime = mtime
						profile_data_path = candidate

		if profile_data_path is None :
			device_guid = self.get_device_guid();
			profile_data_path = derived_dir + "/ProfileData/" + device_guid + "/Coverage.profdata"

		if not os.path.isfile(profile_data_path) :
			print(ColorValues.FAIL + "Coverage data file missing! : " + profile_data_path + ColorValues.END)
			return -1
		
		configuration_build_dir = build_settings["CONFIGURATION_BUILD_DIR"]
		executable_path = build_settings["EXECUTABLE_PATH"]
		executable_file_path = configuration_build_dir + "/" + executable_path
		if not os.path.isfile(executable_file_path) :
			print(ColorValues.FAIL + "executable file missing! : " + executable_file_path + ColorValues.END)
			return -1
		
		# Prefer CURRENT_ARCH / the host arch since that matches the coverage
		# profdata slice. Only fall back to the binary's architecture when the
		# chosen arch isn't actually present in the (possibly fat) binary.
		llvm_cov_arch = build_settings.get("CURRENT_ARCH")
		if not llvm_cov_arch or llvm_cov_arch == "undefined_arch" :
			llvm_cov_arch = platform.machine() or "x86_64"
		try :
			archs = subprocess.check_output(
				["lipo", "-archs", executable_file_path],
				stderr=subprocess.DEVNULL
			).decode().split()
			if archs and llvm_cov_arch not in archs :
				llvm_cov_arch = archs[0]
		except Exception :
			pass  # Fall back to CURRENT_ARCH / platform.machine()
		command = "xcrun llvm-cov report -instr-profile " + profile_data_path + " -arch=\"" + llvm_cov_arch + "\" -use-color " + executable_file_path
		print(command)
		p = subprocess.Popen(command, stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell = True)
		
		output = p.communicate()
		
		last_line = None
		for line in output[0].decode(sys.stdout.encoding).split("\n") :
			if (len(line.strip()) > 0) :
				last_line = line
		
		sys.stdout.write(output[0].decode(sys.stdout.encoding))
		sys.stderr.write(output[1].decode(sys.stdout.encoding))
		
		last_line = last_line.split()
		# Remove everything but 
		cov_str = re.sub(r"[^0-9.]", "", last_line[3])
		self.coverage = float(cov_str)
		return self.print_coverage(False)
	
	def load_xcresult_json(self, xcresult, kind) :
		# `kind` is 'tests' or 'summary'. Returns parsed JSON or None.
		try :
			raw = subprocess.check_output("xcrun xcresulttool get test-results " + kind + " --path '" + xcresult + "' 2>/dev/null", shell = True)
			return json.loads(raw.decode("utf-8"))
		except Exception :
			return None
	
	def collect_failure_messages(self, nodes, messages) :
		for node in nodes :
			if node.get("nodeType") == "Failure Message" :
				text = node.get("name", "")
				if text :
					messages.append(text)
			self.collect_failure_messages(node.get("children", []) or [], messages)
	
	def collect_test_cases(self, nodes, suite_path, cases) :
		# Only bundles and suites contribute to the JUnit classname; the "Test Plan"
		# wrapper is the same for every case, so it is skipped to avoid noise.
		suite_types = ("Unit test bundle", "UI test bundle", "Test Suite")
		for node in nodes :
			node_type = node.get("nodeType", "")
			name = node.get("name", "")
			children = node.get("children", []) or []
			if node_type == "Test Case" :
				result = node.get("result", "unknown")
				messages = []
				self.collect_failure_messages(children, messages)
				if result == "Failed" :
					status = "failure"
				elif result == "Skipped" :
					status = "skipped"
				else :
					status = "passed"
				cases.append({
					"name" : name,
					"classname" : ".".join([p for p in suite_path if p]) or self.name,
					"status" : status,
					"message" : " ".join(messages).strip(),
					"duration" : node.get("durationInSeconds", 0.0) or 0.0,
				})
			elif node_type in suite_types :
				self.collect_test_cases(children, suite_path + [name], cases)
			else :
				self.collect_test_cases(children, suite_path, cases)
	
	def write_junit_from_tests(self, tests_json, junit_path) :
		# Derive JUnit from the .xcresult (the source of truth) instead of trusting
		# xcbeautify's stdout scraping. When a test *crashes*, the crash kills the
		# test process before xcbeautify sees a result line, so xcbeautify's JUnit
		# silently omits the crashed test (e.g. reports "1 test, 0 failures" when a
		# test actually crashed). The .xcresult still records the crash. xcresulttool
		# has no JUnit export - `get test-results tests --format junit` ignores the
		# flag and prints JSON - so we walk its test tree here. Returns True when a
		# report was written; if it returns False the caller keeps xcbeautify's file.
		cases = []
		self.collect_test_cases(tests_json.get("testNodes", []) or [], [], cases)
		if not cases :
			return False
		total = len(cases)
		failures = sum(1 for c in cases if c["status"] == "failure")
		skipped = sum(1 for c in cases if c["status"] == "skipped")
		attrs = { "name" : self.name, "tests" : str(total), "failures" : str(failures), "skipped" : str(skipped), "errors" : "0" }
		suites = ET.Element("testsuites", attrs)
		suite = ET.SubElement(suites, "testsuite", attrs)
		for c in cases :
			case_attrs = { "name" : c["name"], "classname" : c["classname"] }
			if c["duration"] :
				case_attrs["time"] = "%.3f" % c["duration"]
			case_el = ET.SubElement(suite, "testcase", case_attrs)
			if c["status"] == "failure" :
				fail_el = ET.SubElement(case_el, "failure", { "message" : c["message"] or "Test failed" })
				fail_el.text = c["message"]
			elif c["status"] == "skipped" :
				ET.SubElement(case_el, "skipped")
		ET.ElementTree(suites).write(junit_path, encoding = "utf-8", xml_declaration = True)
		return True
	
	def report_test_failures(self, summary_json) :
		# Print each failing test and its reason directly in the log, and raise an
		# ADO error issue per failure so the reason is visible on the run summary
		# without downloading the .xcresult or expanding the raw build log.
		if not summary_json :
			return
		failures = summary_json.get("testFailures", []) or []
		failed_count = summary_json.get("failedTests", len(failures)) or 0
		if not failures and not failed_count :
			return
		print("")
		print("❌ " + str(failed_count) + " test(s) failed in " + self.name + ":")
		for f in failures :
			name = f.get("testName") or f.get("testIdentifierString") or "Unknown test"
			target = f.get("targetName", "")
			reason = (f.get("failureText") or "no failure message").replace("\n", " ").strip()
			location = (target + " / " + name) if target else name
			print("  • " + location + " — " + reason)
			if in_ado_ci :
				print("##vso[task.logissue type=error]" + self.name + ": " + location + " — " + reason)
		print("")
	
	def report_test_results(self) :
		xcresult = "./build/reports/" + self.name + ".xcresult"
		if not os.path.isdir(xcresult) :
			return
		junit = "./build/reports/" + self.name + ".xml"
		tests_json = self.load_xcresult_json(xcresult, "tests")
		if tests_json :
			self.write_junit_from_tests(tests_json, junit)
		summary_json = self.load_xcresult_json(xcresult, "summary")
		summary = "./build/reports/" + self.name + "-summary.txt"
		subprocess.call("xcrun xcresulttool get test-results summary --path '" + xcresult + "' > '" + summary + "' 2>/dev/null || echo 'Could not extract test-results summary' > '" + summary + "'", shell = True)
		print("##[group]Test results: " + self.name)
		subprocess.call("cat '" + summary + "'", shell = True)
		print("##[endgroup]")
		self.report_test_failures(summary_json)
		if in_ado_ci :
			md = "./build/reports/" + self.name + "-summary.md"
			subprocess.call("{ echo '### Test results: " + self.name + "'; echo; echo '```text'; cat '" + summary + "'; echo '```'; } > '" + md + "'", shell = True)
			print("##vso[task.uploadsummary]" + os.path.abspath(md))
	
	def do_operation(self, operation) :
		exit_code = -1;
		print_operation_start(self.name, operation)
		start_time = timer()
		
		try :
			if (operation == "codecov") :
				exit_code = self.do_codecov()
			elif (operation == "lint") :
				exit_code = self.do_lint()
			else :
				command = self.xcodebuild_command(operation, output_formatter)
				if (operation == "test") :
					subprocess.call("mkdir -p ./build/reports; rm -rf './build/reports/" + self.name + ".xcresult' './build/reports/" + self.name + ".xml' './build/reports/" + self.name + "-summary.txt' './build/reports/" + self.name + "-summary.md'", shell = True)
				if (operation == "build" and self.use_sonarcube == "true" and os.environ.get('TRAVIS') == "true") :
					subprocess.call("rm -rf .sonar; rm -rf build-wrapper-output", shell = True)
					command = "build-wrapper-macosx-x86 --out-dir build-wrapper-output " + command
				print(command)
				exit_code = subprocess.call("set -o pipefail;" + command, shell = True)
				if (operation == "test") :
					self.report_test_results()
			
			if (exit_code != 0) :
				self.failed = True
		except Exception as inst:
			self.failed = True
			print("Failed due to exception in build script")
			tb = traceback.format_exc()
			print(tb)

		print_operation_end(self.name, operation, exit_code, start_time)
		
		print()
		return exit_code
	
	def requires_simulator(self) :
		if self.platform == "Mac" :
			return False
		if "test" in self.operations :
			return True
		return False

def requires_simulator(targets) :
	for target in targets :
		if target.requires_simulator() :
			return True
	return False

def launch_simulator(targets) :
    for target in targets :
        if target.platform == "iOS" :
            print("Booting iOS simulator...")
            command = "xcrun simctl boot " + device_guids.get_ios(ios_sim_device_exact_name)
            
            break
        else :
            print("Booting visionOS simulator...")
            command = "xcrun simctl boot " + device_guids.get_ios(vision_sim_device_exact_name)
            print(command)
            break
    print(command)
    # This spawns a new process without us having to wait for it
    subprocess.Popen(command, shell = True)

clean = True

parser = argparse.ArgumentParser(description='ADAL SDK Build Script')
parser.add_argument('--no-clean', action='store_false', help="Skips the clean build products step")
parser.add_argument('--no-xcpretty', '--no-xcbeautify', dest='use_formatter', action='store_false', help="Show raw xcodebuild output instead of using xcbeautify/xcpretty")
parser.add_argument('--show-build-settings', action='store_true',  help="Show xcodebuild's settings output")
parser.add_argument('--targets', '--target', dest='targets', nargs='+', help="Specify individual targets to run")
args = parser.parse_args()

clean = args.no_clean
use_formatter = args.use_formatter
show_build_settings = args.show_build_settings
output_formatter = select_formatter(use_formatter)
in_ado_ci = os.environ.get("TF_BUILD", "").lower() == "true"

if (args.targets != None) :
	print("Targets specified: " + str(args.targets))

targets = []

for spec in target_specifiers :
	if (args.targets == None or spec["target"] in args.targets) :
		targets.append(BuildTarget(spec))

if requires_simulator(targets) :
    launch_simulator(targets)

# start by cleaning up any derived data that might be lying around
if (clean) :
	derived_folders = set()
	for target in targets :
		build_dir = target.get_build_settings()["BUILD_DIR"]
		derived_dir = os.path.normpath(build_dir + "/../..")
		derived_folders.add(derived_dir)
		print(derived_dir)
	
	for dir in derived_folders :
		print("Deleting " + dir)
		subprocess.call("rm -rf " + dir, shell=True)

for target in targets:
	exit_code = 0
	
	# If show build settings is turned on then grab the build settings at the beginning of
	# the operation to show it at the top of the log
	if show_build_settings :
		target.get_build_settings()
		
	target.start_time = timer()

	for operation in target.operations :
		if (exit_code != 0) :
			break; # If one operation fails, then the others are almost certainly going to fail too

		exit_code = target.do_operation(operation)
	
	target.end_time = timer()

	# Add success/failure state to the build status dictionary
	if (exit_code == 0) :
		print(ColorValues.OK + target.name + " Succeeded" + ColorValues.END)
	else :
		print(ColorValues.FAIL + target.name + " Failed" + ColorValues.END)

final_status = 0

print("\n")

code_coverage = False

# Print out the final result of each operation.
for target in targets :
	if (target.failed) :
		print(ColorValues.FAIL + target.name + " failed." + ColorValues.END + " (" + "{0:.2f}".format(target.end_time - target.start_time) + " seconds)" )
		final_status = 1
	else :
		if ("codecov" in target.operations) :
			code_coverage = True
		print(ColorValues.OK + '\033[92m' + target.name + " succeeded." + ColorValues.END + " (" + "{0:.2f}".format(target.end_time - target.start_time) + " seconds)")

if code_coverage :
	print("\nCode Coverage Results:")
	for target in targets :
		if (target.coverage != None) :
			target.print_coverage(True)

script_end_time = timer()

print(" Total running time: " + "{0:.2f}".format(script_end_time - script_start_time) + " seconds")
# xcodebuild seems to log in stderr instead of stdout. Catching final_status in text file to capture exit code and determine if build failed
# Similar issue : (see https://developer.apple.com/forums/thread/663959)
if (not os.path.exists("./build")) :
    os.makedirs("./build")
os.chdir(r'./build')
status_file = open("status.txt", "w")
status_file.write(str(final_status))
sys.exit(final_status)
