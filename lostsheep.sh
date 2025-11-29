#!/bin/bash

# Ensure Homebrew is installed
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Load Homebrew into the current shell (Apple Silicon or Intel)
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Ensure jq is installed
command -v jq >/dev/null 2>&1 || brew install jq

URL='INSERT_URL_HERE'
username="INSERT_USERNAME_HERE"
password='INSERT_PASSWORD_HERE'
smartGroup=INSERT_SMART_GROUP_ID_HERE

# Encode credentials
encodedCredentials=$(printf "%s:%s" "$username" "$password" | base64)

# Get bearer token
bearerToken=$(curl --silent \
  --request POST \
  --url "$URL/api/v1/auth/token" \
  --header "Authorization: Basic $encodedCredentials")

# Parse token correctly
token=$(echo "$bearerToken" | jq -r '.token')

# Get membership of smart group
ids=($(curl --silent --request GET \
  --url "$URL/api/v2/computer-groups/smart-group-membership/$smartGroup" \
  --header 'Accept: application/json' \
  --header "Authorization: Bearer $token" | jq -r '.members[]?'))

# Loop through IDs and redeploy framework
for id in "${ids[@]}"; do
  if [[ $id -gt 0 ]]; then
    echo "Redeploying framework for computer ID $id"
    curl --request POST \
      --url "$URL/api/v1/jamf-management-framework/redeploy/$id" \
      --header 'Content-Type: application/json' \
      --header "Authorization: Bearer $token"
  else
    echo "Device id {$id} invalid, skipping..."
  fi
done

# Invalidate token
curl --request POST \
  --url "$URL/api/v1/auth/invalidate-token" \
  --header "Authorization: Bearer $token"
exit 0
