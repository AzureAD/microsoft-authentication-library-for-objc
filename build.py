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

build_targets = [
	{
		"name" : "iOS Framework",
		"scheme" : "MSAL (iOS Framework)",
		"operations" : [ "build", "test" ],
		"platform" : "iOS",
	},
	{
		"name" : "iOS Test App",
		"scheme" : "MSAL Test App (iOS)",
		"operations" : [ "build" ],
		"platform" : "iOS",
	},
	{
		"name" : "Mac Framework",
		"scheme" : "MSAL (Mac Framework)",
		"operations" : [ "build", "test" ],
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

def do_ios_build(target, operation) :
	name = target["name"]
	scheme = target["scheme"]
	project = target.get("project")
	workspace = target.get("workspace")

	if (workspace == None) :
		workspace = default_workspace

	print_operation_start(name, operation)

	command = "xcodebuild " + operation
	if (project != None) :
		command += " -project " + project
	else :
		command += " -workspace " + workspace
		
	command += " -scheme \"" + scheme + "\" -configuration " + default_config + " " + ios_sim_flags + " " + ios_sim_dest
	if (use_xcpretty) :
		command += " | xcpretty"
		
	print command
	exit_code = subprocess.call("set -o pipefail;" + command, shell = True)

	print_operation_end(name, operation, exit_code)
	return exit_code

def do_mac_build(target, operation) :
	arch = target.get("arch")
	name = target["name"]
	scheme = target["scheme"]

	print_operation_start(name, operation)

	command = "xcodebuild " + operation + " -workspace " + default_workspace + " -scheme \"" + scheme + "\" -configuration " + default_config

	if (arch != None) :
		command += " -destination 'arch=" + arch + "'"

	if (use_xcpretty) :
		command += " | xcpretty"

	print command
	exit_code = subprocess.call("set -o pipefail;" + command, shell = True)

	print_operation_end(name, operation, exit_code)

	return exit_code

build_status = dict()

def check_dependencies(target) :
	dependencies = target.get("dependencies")
	if (dependencies == None) :
		return True

	for dependency in dependencies :
		dependency_status = build_status.get(dependency)
		if (dependency_status == None) :
			print tclr.SKIP + "Skipping " + name + " dependency " + dependency + " not built yet." + tclr.END
			build_status[name] = "Skipped"
			return False

		if (build_status[dependency] != "Succeeded") :
			print tclr.SKIP + "Skipping " + name + " dependency " + dependency + " failed." + tclr.END
			build_status[name] = "Skipped"
			return False

	return True

clean = True

for arg in sys.argv :
	if (arg == "--no-clean") :
		clean = False
	if (arg == "--no-xcpretty") :
		use_xcpretty = False

# start by cleaning up any derived data that might be lying around
if (clean) :
	subprocess.call("rm -rf ~/Library/Developer/Xcode/DerivedData/MSAL-*", shell=True)

for target in build_targets:
	exit_code = 0
	name = target["name"]
	platform = target["platform"]

	# If we don't have the dependencies for this target built yet skip it.
	if (not check_dependencies(target)) :
		continue

	for operation in target["operations"] :
		if (exit_code != 0) :
			break; # If one operation fails, then the others are almost certainly going to fail too

		if (platform == "iOS") :
			exit_code = do_ios_build(target, operation)
		elif (platform == "Mac") :
			exit_code = do_mac_build(target, operation)
		else :
			raise Exception('Unrecognized platform type ' + platform)

	if (exit_code == 0) :
		print tclr.OK + name + " Succeeded" + tclr.END
		build_status[name] = "Succeeded"
	else :
		print tclr.FAIL + name + " Failed" + tclr.END
		build_status[name] = "Failed"

final_status = 0

print "\n"

for target in build_targets :
	project = target["name"]
	status = build_status[project]
	if (status == "Failed") :
		print tclr.FAIL + project + " failed." + tclr.END
		final_status = 1
	elif (status == "Skipped") :
		print tclr.SKIP + '\033[93m' + project + " skipped." + tclr.END
		final_status = 1
	elif (status == "Succeeded") :
		print tclr.OK + '\033[92m' + project + " succeeded." + tclr.END
	else :
		raise Exception('Unrecognized status: ' + status)

sys.exit(final_status)
