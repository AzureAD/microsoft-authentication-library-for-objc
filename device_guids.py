#!/usr/bin/env python
import re
import subprocess
import platform
import os
import sys


def is_version_higher(orig_version, new_version) :
	if new_version[0] > orig_version[0] :
		return True
	if new_version[0] < orig_version[0] :
		return False
	if new_version[1] > orig_version[1] :
		return True
	if new_version[1] < orig_version[1] :
		return False
	if new_version[2] > orig_version[2] :
		return True
	return False

def get_guid_i(device) :
	device_regex = re.compile("[A-Za-z0-9 ]+ ?(?:\\(([0-9.]+)\\))? \\[([A-F0-9-]+)\\]")
	version_regex = re.compile("([0-9]+)\\.([0-9]+)(?:\\.([0-9]+))?")
	
	command = "instruments -s devices"
	print "travis_fold:start:Devices"
	p = subprocess.Popen(command, stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell = True)
	
	# Sometimes the hostname comes back with the proper casing, sometimes not. Using a
	# case insensitive regex ensures we work either way
	dev_name_regex = re.compile("^" + device + " \\(", re.I)
	
	latest_os_device = None
	latest_os_version = None
	
	for line in p.stdout :
		sys.stdout.write(line)
		if (dev_name_regex.match(line) == None) :
			continue
		
		match = device_regex.match(line)
		
		# Regex won't match simulators with apple watches...
		if (match == None) : 
			continue
		
		version_match = version_regex.match(match.group(1))
		
		minor_version = version_match.group(3)
		if (minor_version ==  None) :
			minor_version = 0
		else :
			minor_version = int(minor_version)
		version_tuple = (int(version_match.group(1)), int(version_match.group(2)), minor_version)
		
		if latest_os_version == None or is_version_higher(latest_os_version, version_tuple) :
			latest_os_device = match.group(2)
			latest_os_version = version_tuple
	
	print "travis_fold:end:Devices"
	
	return latest_os_device

def get_guid(device) :
	guid = get_guid_i(device)
	if (guid == None) :
		print_failure(device)
	return guid

def print_failure(device) :
	print "Failed to find GUID for device : " + device
	subprocess.call("instruments -s devices", shell=True)
	raise Exception("Failed to get device GUID")

def get_ios(device) :
	if (device in get_ios.guid) :
		return get_ios.guid[device]
	
	guid = get_guid(device)
	get_ios.guid[device] = guid
	return guid

get_ios.guid = {}

def get_mac() :
	if (get_mac.guid != None) :
		return get_mac.guid
	
	guid = subprocess.check_output("system_profiler SPHardwareDataType | awk '/UUID/ { print $3; }'", shell=True)
	guid = guid.strip()
	get_mac.guid = guid
	return guid

get_mac.guid = None