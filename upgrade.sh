#!/usr/bin/env bash

# Simple wrapper script to run the FT2 tools installer in upgrade mode
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )"

# Display banner
echo "====================================="
echo "FT2 Tools Upgrade Utility"
echo "====================================="
echo "This script will automatically detect and upgrade installed FT2 components."
echo

# Make tools installer executable (in case it's not)
chmod +x "${SCRIPT_DIR}/ft2_tools_installer.sh"

# Run the installer with the upgrade flag
"${SCRIPT_DIR}/ft2_tools_installer.sh" --upgrade "$@"