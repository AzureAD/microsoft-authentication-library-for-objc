import subprocess
import base64
import os
import json

def run_az_command(command):
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            return result.stdout.strip()
        else:
            print("Error:", result.stderr.strip())
            return None
    except Exception as e:
        print("Exception:", str(e))
        return None
# 2 Loading conf.json file as base64 encoding form lab keyvault
print("Loading conf.json file...")
output_1 = ""
output_2 = ""
# 2.1 Loading the 1st half and formatting 
az_command_1 = "az keyvault secret show --name \"appleautomationconfjsonfile1\" --vault-name \"buildautomation\" --query \"value\""
output_1_without_formatting = run_az_command(az_command_1)
output_1 = output_1_without_formatting.replace('\n', '').replace('"', '')
# 2.2 Loading the 2nd half and and formatting
az_command_2 = "az keyvault secret show --name \"appleautomationconfjsonfile2\" --vault-name \"buildautomation\" --query \"value\""
output_2_without_formatting = run_az_command(az_command_2)
# 3.1 Combine 2 parts, decode and write into local conf.json file
output_2 = output_2_without_formatting.replace('\n', '').replace('"', '')
base64_encoded_conf_file = output_1 + "" + output_2
# 3.2 Decode the back to text
decoded_bytes = base64.b64decode(base64_encoded_conf_file)
decoded_string = decoded_bytes.decode('utf-8')  # Assuming the decoded data is in UTF-8 encoding
# 3.3 Write into local conf.json file
print("Generating conf.json file...")
file_path = "conf.json"
with open(file_path, "w") as text_file:
    text_file.write(decoded_string)
current_file_path = os.path.abspath(file_path)
print("conf.json file was written successfully at\n", current_file_path)
print("Please move conf.json file accordingly for broker automation (e.g. aadtests at root folder)")
