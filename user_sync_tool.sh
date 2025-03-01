#!/bin/bash

# Prompt for server details
read -p "Enter the TrueNAS server IP: " SERVER_IP
read -p "Enter the username: " API_USER
read -s -p "Enter the password: " API_PASSWORD
echo

# Fetch hostname or default to IP
API_URL="http://$SERVER_IP/api/v2.0"
HOSTNAME=$(curl -s -u "$API_USER:$API_PASSWORD" -X GET "$API_URL/system/info/" | jq -r '.hostname')
if [[ -z "$HOSTNAME" ]]; then
  HOSTNAME="$SERVER_IP"
fi

# File names with IP or hostname
GROUPS_FILE="groups_${HOSTNAME}.csv"
USERS_FILE="users_${HOSTNAME}.csv"

# Fetch and save non-builtin groups
curl -s -u "$API_USER:$API_PASSWORD" -X GET "$API_URL/group" | \
jq -r '.[] | select(.builtin == false) | "\(.group),\(.id),\(.gid),\(.smb)"' > "$GROUPS_FILE"

# Fetch and save non-builtin users
curl -s -u "$API_USER:$API_PASSWORD" -X GET "$API_URL/user" | \
jq -r '.[] | select(.builtin == false) | "\(.full_name),\(.username),\(.group.bsdgrp_gid),\(.uid),\(.smb)"' > "$USERS_FILE"

echo "Non-builtin groups saved to $GROUPS_FILE"
echo "Non-builtin users saved to $USERS_FILE"

# Prompt user to proceed with creation
read -p "Do you want to create the groups and users on the server? (yes/no): " PROCEED
if [[ "$PROCEED" != "yes" ]]; then
  echo "Exiting without creating groups or users."
  exit 0
fi

# Function to create groups
declare -A GROUP_IDS
create_groups() {
  while IFS=',' read -r group_name group_id gid smb; do
    # Create the group
    echo "Creating group: $group_name"
    group_info=$(midclt call group.create "{
      \"name\": \"$group_name\",
      \"gid\": $gid,
      \"smb\": $smb
    }" 2>/dev/null)
    
    # Allow some time for the system to process
    sleep 2

    # Query the group to fetch the system ID
    existing_group=$(midclt call group.query "[[\"name\", \"=\", \"$group_name\"]]" 2>/dev/null)
    if [[ "$existing_group" != "[]" ]]; then
      system_group_id=$(echo "$existing_group" | jq -r '.[0].id' 2>/dev/null)
      if [[ -n "$system_group_id" ]]; then
        GROUP_IDS["$group_name"]=$system_group_id
        echo "Group '$group_name' created with system ID: $system_group_id"
      else
        echo "Error: Failed to parse system ID for group '$group_name'."
      fi
    else
      echo "Error: Group '$group_name' not found after creation."
    fi
  done < "$GROUPS_FILE"
}


# Function to fetch group IDs after creation
fetch_group_ids() {
  while IFS=',' read -r group_name group_id gid smb; do
    existing_group=$(midclt call group.query "[[\"name\", \"=\", \"$group_name\"]]" 2>/dev/null)
    if [[ "$existing_group" != "[]" ]]; then
      system_group_id=$(echo "$existing_group" | jq -r '.[0].id' 2>/dev/null)
      if [[ -n "$system_group_id" ]]; then
        GROUP_IDS["$group_name"]=$system_group_id
        echo "Group '$group_name' verified with system ID: $system_group_id"
      else
        echo "Error: Unable to fetch system ID for group '$group_name'."
      fi
    else
      echo "Error: Group '$group_name' not found after creation."
    fi
  done < "$GROUPS_FILE"
}

# Function to create users
create_users() {
  while IFS=',' read -r full_name username gid uid smb; do
    # Fetch the system-generated group ID
    group_name=$(grep ",$gid," "$GROUPS_FILE" | cut -d',' -f1)
    system_group_id=${GROUP_IDS["$group_name"]}
    if [[ -z "$system_group_id" ]]; then
      echo "Error: No system ID found for group '$group_name' (gid: $gid)"
      continue
    fi

    # Check if the user already exists
    existing_user=$(midclt call user.query "[[\"username\", \"=\", \"$username\"]]" 2>/dev/null)
    if [[ "$existing_user" != "[]" ]]; then
      echo "User '$username' already exists. Skipping."
      continue
    fi

    echo "Creating user: $username"
    midclt call user.create "{
      \"username\": \"$username\",
      \"full_name\": \"$full_name\",
      \"password\": \"$uid\",
      \"uid\": $uid,
      \"group\": $system_group_id,
      \"smb\": $smb
    }" 2>/dev/null
  done < "$USERS_FILE"
}

# Main Execution
echo "Starting group creation..."
create_groups
echo "Groups created successfully."

echo "Verifying group IDs..."
fetch_group_ids
echo "Group IDs verified successfully."

echo "Starting user creation..."
create_users
echo "Users created successfully."
