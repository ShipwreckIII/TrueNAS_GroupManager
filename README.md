# User Sync Tool for TrueNAS

A Bash script to automate user and group synchronization with a TrueNAS server via API.

## Features
- Fetches non-builtin users and groups from TrueNAS.
- Saves them to CSV files for reference.
- Creates users and groups on the TrueNAS server.
- Ensures group IDs are correctly assigned.

## Requirements
- TrueNAS API access
- `curl` and `jq` installed on the system
- Midclt (`midclt call`) for group and user creation

## Usage
1. Clone the repository:
   ```bash
   git clone https://github.com/ShipwreckIII/TrueNAS_GroupManager.git
   cd TrueNAS_GroupManager
2. Run the script:
chmod +x user_sync_tool.sh
./user_sync_tool.sh
3. Enter the required details when prompted:
TrueNAS server IP
Username and Password

4. The script will:
Fetch existing groups and users.
Save them in groups_<hostname>.csv and users_<hostname>.csv.
Prompt before creating new users and groups.

5. Notes
The script uses API authentication, so ensure proper access rights.
User passwords are set using their UID (modify as needed).
Group IDs must be fetched correctly before creating users.

6. License
MIT License

## Author
Eng.Ahmad abd Al-Hadi


Let me know if you need changes