#!/usr/bin/env python

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
import argparse
import device_guids

from timeit import default_timer as timer

script_start_time = timer()

ios_sim_device = "iPhone 6"
ios_sim_dest = "-destination 'platform=iOS Simulator,name=" + ios_sim_device + ",OS=latest'"
ios_sim_flags = "-sdk iphonesimulator CODE_SIGN_IDENTITY=\"\" CODE_SIGNING_REQUIRED=NO"

default_workspace = "MSAL.xcworkspace"
default_config = "Debug"

use_xcpretty = True
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
		"operations" : [ "build", "test", "codecov" ],
		"min_warn_codecov" : 70.0,
		"platform" : "iOS",
	},
	{
		"name" : "iOS Test App",
		"scheme" : "MSAL Test App (iOS)",
		"operations" : [ "build" ],
		"platform" : "iOS",
	},
	{
		"name" : "Sample iOS App",
		"scheme" : "SampleAppiOS",
		"workspace" : "Samples/ios/SampleApp.xcworkspace",
		"operations" : [ "build" ],
		"platform" : "iOS",
	},
    {
        "name" : "Sample iOS App-iOS",
        "scheme" : "SampleAppiOS-Swift",
        "workspace" : "Samples/ios/SampleApp.xcworkspace",
        "operations" : [ "build" ],
        "platform" : "iOS",
    },
	{
		"name" : "Mac Framework",
		"scheme" : "MSAL (Mac Framework)",
		"operations" : [ "build", "test", "codecov" ],
		"min_warn_codecov" : 70.0,
		"platform" : "Mac"
	},
]

def print_operation_start(name, operation) :
	print ColorValues.HDR + "Beginning " + name + " [" + operation + "]" + ColorValues.END
	print "travis_fold:start:" + (name + "_" + operation).replace(" ", "_")

def print_operation_end(name, operation, exit_code, start_time) :
	print "travis_fold:end:" + (name + "_" + operation).replace(" ", "_")
	
	end_time = timer()

	if (exit_code == 0) :
		print ColorValues.OK + name + " [" + operation + "] Succeeded" + ColorValues.END + " (" + "{0:.2f}".format(end_time - start_time) + " seconds)"
	else :
		print ColorValues.FAIL + name + " [" + operation + "] Failed" + ColorValues.END + " (" + "{0:.2f}".format(end_time - start_time) + " seconds)"

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
	
	def xcodebuild_command(self, operation, xcpretty) :
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
		
		if (operation != None and "codecov" in self.operations) :
			command += " -enableCodeCoverage YES"

		if (self.platform == "iOS") :
			command += " " + ios_sim_flags + " " + ios_sim_dest
		
		if (xcpretty) :
			command += " | xcpretty"
		
		return command
	
	def get_build_settings(self) :
		"""
		Retrieve the build settings from xcodebuild and return thm in a dictionary
		"""
		
		if (self.build_settings != None) :
			return self.build_settings
		
		print "Retrieving Build Settings for " + self.name
		if (show_build_settings) :
			print "travis_fold:start:" + (self.name + "_settings").replace(" ", "_")
				
		command = self.xcodebuild_command(None, False)
		command += " -showBuildSettings"
		print command
		
		start = timer()
        
		settings_blob = subprocess.check_output(command, shell=True)
		if (show_build_settings) :
			print settings_blob
			print "travis_fold:end:" + (self.name + "_settings").replace(" ", "_")
		
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
		
		print "Retrieved Build Settings (" + "{0:.2f}".format(end - start) + " sec)"
		
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
			return device_guids.get_ios(ios_sim_device)
		
		if (self.platform == "Mac") :
			return device_guids.get_mac()
		
		raise Exception("Unsupported platform: \"" + "\", valid platforms are \"iOS\" and \"Mac\"")
	
	def do_codecov(self) :
		"""
		Print a code coverage report using llvm_cov, retrieve the coverage result and
		print out an error if it is below the minimum requirement
		"""
		build_settings = self.get_build_settings();
		build_dir = build_settings["BUILD_DIR"]
		derived_dir = os.path.normpath(build_dir + "/..")
		device_guid = self.get_device_guid();
		
		profile_data_path = derived_dir + "/ProfileData/" + device_guid + "/Coverage.profdata"
		if not os.path.isfile(profile_data_path) :
			print ColorValues.FAIL + "Coverage data file missing! : " + profile_data_path + ColorValues.END
			return -1
		
		configuration_build_dir = build_settings["CONFIGURATION_BUILD_DIR"]
		executable_path = build_settings["EXECUTABLE_PATH"]
		executable_file_path = configuration_build_dir + "/" + executable_path
		if not os.path.isfile(executable_file_path) :
			print ColorValues.FAIL + "executable file missing! : " + executable_file_path + ColorValues.END
			return -1
		
		command = "xcrun llvm-cov report -instr-profile " + profile_data_path + " -arch=\"x86_64\" -use-color " + executable_file_path
		print command
		p = subprocess.Popen(command, stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell = True)
		
		output = p.communicate()
		
		last_line = None
		for line in output[0].split("\n") :
			if (len(line.strip()) > 0) :
				last_line = line
		
		sys.stdout.write(output[0])
		sys.stderr.write(output[1])
		
		last_line = last_line.split()
		# Remove everything but 
		cov_str = re.sub(r"[^0-9.]", "", last_line[3])
		self.coverage = float(cov_str)
		return self.print_coverage(False)
	
	def do_operation(self, operation) :
		exit_code = -1;
		print_operation_start(self.name, operation)
		start_time = timer()
		
		try :
			if (operation == "codecov") :
				exit_code = self.do_codecov()
			else :
				command = self.xcodebuild_command(operation, use_xcpretty)
				if (operation == "build" and self.use_sonarcube == "true" and os.environ.get('TRAVIS') == "true") :
					subprocess.call("rm -rf .sonar; rm -rf build-wrapper-output", shell = True)
					command = "build-wrapper-macosx-x86 --out-dir build-wrapper-output " + command
				print command
				exit_code = subprocess.call("set -o pipefail;" + command, shell = True)
			
			if (exit_code != 0) :
				self.failed = True
		except Exception as inst:
			self.failed = True
			print "Failed due to exception in build script"
			tb = traceback.format_exc()
			print tb

		print_operation_end(self.name, operation, exit_code, start_time)
		
		print 
		return exit_code
	
	def requires_simulator(self) :
		if self.platform is not "iOS" :
			return False
		if "test" in self.operations :
			return True
		return False

def requires_simulator(targets) :
	for target in targets :
		if target.requires_simulator() :
			return True
	return False

def launch_simulator() :
	print "Booting simulator..."
	command = "xcrun simctl boot " + device_guids.get_ios(ios_sim_device)
	print command
	
	# This spawns a new process without us having to wait for it
	subprocess.Popen(command, shell = True)

clean = True

parser = argparse.ArgumentParser(description='ADAL SDK Build Script')
parser.add_argument('--no-clean', action='store_false', help="Skips the clean build products step")
parser.add_argument('--no-xcpretty', action='store_false', help="Show raw xcodebuild output instead of using xcpretty")
parser.add_argument('--show-build-settings', action='store_true',  help="Show xcodebuild's settings output")
parser.add_argument('--targets', nargs='+', help="Specify individual targets to run")
args = parser.parse_args()

clean = args.no_clean
use_xcpretty = args.no_xcpretty
show_build_settings = args.show_build_settings

if (args.targets != None) :
	print "Targets specified: " + str(args.targets)

targets = []

for spec in target_specifiers :
	if (args.targets == None or spec["target"] in args.targets) :
		targets.append(BuildTarget(spec))

if requires_simulator(targets) :
	launch_simulator()

# start by cleaning up any derived data that might be lying around
if (clean) :
	derived_folders = set()
	for target in targets :
		build_dir = target.get_build_settings()["BUILD_DIR"]
		derived_dir = os.path.normpath(build_dir + "/../..")
		derived_folders.add(derived_dir)
		print derived_dir
	
	for dir in derived_folders :
		print "Deleting " + dir
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
		print ColorValues.OK + target.name + " Succeeded" + ColorValues.END
	else :
		print ColorValues.FAIL + target.name + " Failed" + ColorValues.END

final_status = 0

print "\n"

code_coverage = False

# Print out the final result of each operation.
for target in targets :
	if (target.failed) :
		print ColorValues.FAIL + target.name + " failed." + ColorValues.END + " (" + "{0:.2f}".format(target.end_time - target.start_time) + " seconds)"
		final_status = 1
	else :
		if ("codecov" in target.operations) :
			code_coverage = True
		print ColorValues.OK + '\033[92m' + target.name + " succeeded." + ColorValues.END + " (" + "{0:.2f}".format(target.end_time - target.start_time) + " seconds)"

if code_coverage :
	print "\nCode Coverage Results:"
	for target in targets :
		if (target.coverage != None) :
			target.print_coverage(True)

script_end_time = timer()

print "Total running time: " + "{0:.2f}".format(script_end_time - script_start_time) + " seconds"

sys.exit(final_status)
