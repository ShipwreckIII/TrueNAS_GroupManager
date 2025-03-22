#!/bin/bash

# Define temp file and log file
TEMP_FILE=$(mktemp)
LOG_FILE="deleted_users.log"

# Query all users with UID >= 1000 and < 30000, save to temp file
echo "Fetching non-built-in users (UID >= 1000 and < 30000)..."
midclt call user.query '[["uid", ">=", 1000], ["uid", "<", 30000]]' | jq -c '.[]' > "$TEMP_FILE"

echo "Starting user deletion process..."
echo "Deleted users log - $(date)" > "$LOG_FILE"

# Check if the temp file contains users
if [ ! -s "$TEMP_FILE" ]; then
    echo "No users found to delete. Exiting."
    rm -f "$TEMP_FILE"
    exit 0
fi

# Loop through each user in the temp file
while IFS= read -r user; do
    user_id=$(echo "$user" | jq -r '.id // empty')
    username=$(echo "$user" | jq -r '.username // empty')

    if [[ -n "$user_id" && -n "$username" ]]; then
        echo "Attempting to delete user: $username (ID: $user_id)..."
        if midclt call user.delete "$user_id" > /dev/null 2>&1; then
            echo "Successfully deleted user: $username"
            echo "$username" >> "$LOG_FILE"
        else
            echo "Failed to delete user: $username"
        fi
    else
        echo "Skipping invalid user entry: $user"
    fi
done < "$TEMP_FILE"

# Remove the temp file
rm -f "$TEMP_FILE"

echo "User deletion process completed."
echo "Deleted users log saved at $LOG_FILE"
