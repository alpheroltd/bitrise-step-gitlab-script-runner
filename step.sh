#!/bin/bash

set -e

CONFIG_ERROR_MESSAGE=""

# input validation. check everything is set
if [ -z "$gitlab_domain" ]; then
  CONFIG_ERROR_MESSAGE+="[ERROR] A gitlab domain is required!\n"
fi

if [ -z "$gitlab_project_id" ]; then
  CONFIG_ERROR_MESSAGE+="[ERROR] A gitlab project ID is required!\n"
fi

if [ -z "$gitlab_file_path" ]; then
  CONFIG_ERROR_MESSAGE+="[ERROR] A file path within your repository is required!\n"
fi

if [ -z "$gitlab_file_ref" ]; then
  CONFIG_ERROR_MESSAGE+="[ERROR] A git reference is required! Try a branch or tag name\n"
fi

if [ ! -z "$CONFIG_ERROR_MESSAGE" ]; then
    echo "[ERROR] Configuration error"
    echo "$CONFIG_ERROR_MESSAGE"
    exit 1
fi

echo """
Configuration:
  gitlab_api_token: $gitlab_api_token
  gitlab_domain: $gitlab_domain
  gitlab_project_id: $gitlab_project_id
  gitlab_file_path: $gitlab_file_path 
  gitlab_file_ref: $gitlab_file_ref 
  gitlab_file_sha256: $gitlab_file_sha256
  script_args: $script_args
  download_path: $download_path
"""

# if download_path is undefined then fallback to the file's path in the repo
if [ -z "$download_path" ]; then
    download_path="$gitlab_file_path"
fi

# construct the full URL of the file
GITLAB_FILE_URI="https://$gitlab_domain/api/v4/projects/$gitlab_project_id/repository/files/$gitlab_file_path/raw?ref=$gitlab_file_ref"

echo "[INFO] Fetching script from $GITLAB_FILE_URI"

RESPONSE_CODE=$(curl --header "PRIVATE-TOKEN: $gitlab_api_token" \
  "$GITLAB_FILE_URI" \
  --create-dirs --output "$download_path" \
  -w "%{response_code}")

if [ ! "$RESPONSE_CODE" = "200" ]; then
    echo "[ERROR] Download failed! HTTP Code: $RESPONSE_CODE"
    echo "[ERROR] Please check your API token and the correctness of the source path $GITLAB_FILE_URI"
    rm $download_path
    exit 1
fi

echo "gitlab_file_sha256: $gitlab_file_sha256"
if [ ! -z "$gitlab_file_sha256" ]; then
    FILE_SHA256=$(shasum -a 256 "$download_path" | head -c 64)
    if [ "$gitlab_file_sha256" = "$FILE_SHA256" ]; then
        echo "[INFO] Downloaded file matches the expected SHA256 hash"
    else
        echo "[ERROR] $download_path does not match the expected SHA256 hash"
        exit 1
    fi
else
    echo "[INFO] It is highly recommened to provide a SHA256 hash of the file"
    echo "[INFO] Verifying the file's checksum is basic way to check that the file has not been tampered"
fi

if [ "$run_script" = "yes" ]; then
    echo "[INFO] Running script '$download_path'..."
    "$download_path $script_args" | echo
fi

script_result=$?
exit ${script_result}