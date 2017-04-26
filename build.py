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
import sys
import re

ios_sim_dest = "-destination 'platform=iOS Simulator,name=iPhone 6,OS=latest'"
ios_sim_flags = "-sdk iphonesimulator CODE_SIGN_IDENTITY=\"\" CODE_SIGNING_REQUIRED=NO"

default_workspace = "MSAL.xcworkspace"
default_config = "Debug"

use_xcpretty = True

class tclr:
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
		"name" : "Mac Framework",
		"scheme" : "MSAL (Mac Framework)",
		"operations" : [ "build", "test", "codecov" ],
		"min_warn_codecov" : 70.0,
		"platform" : "Mac"
	},
	{
		"name" : "Mac Test App",
		"scheme" : "MSAL Test App (Mac)",
		"operations" : [ "build" ],
		"platform" : "Mac",
	},
]

def print_operation_start(name, operation) :
	print tclr.HDR + "Beginning " + name + " [" + operation + "]" + tclr.END
	print "travis_fold:start:" + (name + "_" + operation).replace(" ", "_")

def print_operation_end(name, operation, exit_code) :
	print "travis_fold:end:" + (name + "_" + operation).replace(" ", "_")

	if (exit_code == 0) :
		print tclr.OK + name + " [" + operation + "] Succeeded" + tclr.END
	else :
		print tclr.FAIL + name + " [" + operation + "] Failed" + tclr.END

class BuildTarget:
	def __init__(self, target):
		self.name = target["name"]
		self.project = target.get("project")
		self.workspace = target.get("workspace")
		if (self.workspace == None and self.project == None) :
			self.workspace = default_workspace
		self.scheme = target["scheme"]
		self.dependencies = target.get("dependencies")
		self.operations = target["operations"]
		self.platform = target["platform"]
		self.build_settings = None
		self.min_codecov = target.get("min_codecov")
		self.min_warn_codecov = target.get("min_warn_codecov")
		self.coverage = None
		self.failed = False
		self.skipped = False
	
	def xcodebuild_command(self, operation, xcpretty) :
		"""
		Generate and return an xcodebuild command string based on the ivars and operation provided.
		"""
		command = "xcodebuild "
		if (operation != None) :
			command += operation + " "
		
		if (self.project != None) :
			command += " -project " + self.project
		else :
			command += " -workspace " + self.workspace
		
		command += " -scheme \"" + self.scheme + "\" -configuration " + default_config
		
		if (operation == "test" and "codecov" in self.operations) :
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
		
		command = self.xcodebuild_command(None, False)
		command += " -showBuildSettings"
		
		settings_blob = subprocess.check_output(command, shell=True)
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
		
		return settings
		
	def print_coverage(self, printName) :
		"""
		Print a summary of the code coverage results with the proper coloring and
		return -1 if the coverage is below the minimum required.
		"""
		if (self.coverage == None) :
			return 0;
			
		printed = False
		
		if (self.min_warn_codecov != None) :
			if (self.coverage < self.min_warn_codecov) :
				sys.stdout.write(tclr.WARN)
				if (printName) :
					sys.stdout.write(self.name + ": ")
				sys.stdout.write(str(self.coverage) + "% coverage is below the recommended minimum requirement: " + str(self.min_warn_codecov) + "%" + tclr.END + "\n")
				printed = True
				
		if (self.min_codecov != None) :
			if (self.coverage < self.min_codecov) :
				sys.stdout.write(tclr.FAIL)
				if (printName) :
					sys.stdout.write(self.name + ": ")
				sys.stdout.write(str(self.coverage) + "% coverage is below the minimum requirement: " + str(self.min_codecov) + "%" + tclr.END + "\n")
				return -1
		
		if (not printed) :
			sys.stdout.write(tclr.OK)
			if (printName) :
				sys.stdout.write(self.name + ": ")
			sys.stdout.write(str(self.coverage) + "%" + tclr.END + "\n")
			
		return 0
		
	
	def do_codecov(self) :
		"""
		Print a code coverage report using llvm_cov, retrieve the coverage result and
		print out an error if it is below the minimum requirement
		"""
		build_settings = self.get_build_settings();
		codecov_dir = build_settings["OBJROOT"] + "/CodeCoverage"
		executable_path = build_settings["EXECUTABLE_PATH"]
		config = build_settings["CONFIGURATION"]
		platform_name = build_settings.get("EFFECTIVE_PLATFORM_NAME")
		if (platform_name == None) :
			platform_name = ""
		
		command = "xcrun llvm-cov report -instr-profile Coverage.profdata -arch=\"x86_64\" -use-color Products/" + config + platform_name + "/" + executable_path
		p = subprocess.Popen(command, cwd = codecov_dir, stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell = True)
		
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
		
		try :
			if (operation == "codecov") :
				exit_code = self.do_codecov()
			else :
				command = self.xcodebuild_command(operation, use_xcpretty)
				print command
				exit_code = subprocess.call("set -o pipefail;" + command, shell = True)
			
			if (exit_code != 0) :
				self.failed = True
		except Exception as inst:
			self.failed = True
			print "Failed due to exception in build script"
			print type(inst)
			print inst.args
			print inst

		print_operation_end(self.name, operation, exit_code)
		return exit_code

clean = True

for arg in sys.argv :
	if (arg == "--no-clean") :
		clean = False
	if (arg == "--no-xcpretty") :
		use_xcpretty = False

targets = []

for spec in target_specifiers :
	targets.append(BuildTarget(spec))

# start by cleaning up any derived data that might be lying around
if (clean) :
	derived_folders = set()
	for target in targets :
		objroot = target.get_build_settings()["OBJROOT"]
		trailing = "/Build/Intermediates"
		derived_dir = objroot[:-len(trailing)]
		derived_folders.add(derived_dir)
	
	for dir in derived_folders :
		print "Deleting " + dir
		subprocess.call("rm -rf " + dir, shell=True)


for target in targets:
	exit_code = 0

	for operation in target.operations :
		if (exit_code != 0) :
			break; # If one operation fails, then the others are almost certainly going to fail too

		exit_code = target.do_operation(operation)

	# Add success/failure state to the build status dictionary
	if (exit_code == 0) :
		print tclr.OK + target.name + " Succeeded" + tclr.END
	else :
		print tclr.FAIL + target.name + " Failed" + tclr.END

final_status = 0

print "\n"

code_coverage = False

# Traverse the build_status dictionary for all the targets and print out the final
# result of each operation.
for target in targets :
	if (target.failed) :
		print tclr.FAIL + target.name + " failed." + tclr.END
		final_status = 1
	else :
		if ("codecov" in target.operations) :
			code_coverage = True
		print tclr.OK + '\033[92m' + target.name + " succeeded." + tclr.END

if code_coverage :
	print "\nCode Coverage Results:"
	for target in targets :
		if (target.coverage != None) :
			target.print_coverage(True)

sys.exit(final_status)
