#!/usr/bin/env bash

# FT2 Local Tools Installer
# This script installs support applications for Fermentrack 2:
# - Serial to Fermentrack
# - BrewFlasher Command Line Edition
# - TiltBridge Junior

# Colors for terminal output
green=$(tput setaf 76)
red=$(tput setaf 1)
tan=$(tput setaf 3)
reset=$(tput sgr0)
myPath="$( cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )"

# Default settings
PACKAGE_NAME="FT2 Local Tools Installer"
INTERACTIVE=1
INSTALL_SERIAL=0
INSTALL_BREWFLASHER=0
INSTALL_TILTBRIDGE=0
UPGRADE_MODE=0
INSTALL_LOG="./install.log"
USE_CUSTOM_WHEELS=0

# URLs for installation packages
SERIAL_TO_FERMENTRACK_WHEEL_URL="https://github.com/thorrak/serial_to_fermentrack/releases/download/v0.0.4/serial_to_fermentrack-0.0.4-py3-none-any.whl"
MIN_PYTHON_VERSION="3.9.0"

# Help text
function usage() {
    echo "Usage: $0 [-h] [-n] [-s] [-b] [-t] [--upgrade]" 1>&2
    echo "Options:"
    echo "  -h                This help"
    echo "  -n                Run non-interactive installation"
    echo "  -s                Install Serial to Fermentrack"
    echo "  -b                Install BrewFlasher Command Line Edition"
    echo "  -t                Install TiltBridge Junior"
    echo "  --upgrade         Upgrade mode - automatically detect and update installed components"
    exit 1
}

# Handle long options
for arg in "$@"; do
  case "$arg" in
    --upgrade)
      UPGRADE_MODE=1
      shift
      ;;
  esac
done

while getopts "nhsbt" opt; do
  case ${opt} in
    n)
      INTERACTIVE=0  # Silent/Non-interactive Mode
      ;;
    s)
      INSTALL_SERIAL=1  # Install Serial to Fermentrack
      ;;
    b)
      INSTALL_BREWFLASHER=1  # Install BrewFlasher Command Line Edition
      ;;
    t)
      INSTALL_TILTBRIDGE=1  # Install TiltBridge Junior
      ;;
    h)
      usage
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      exit 1
      ;;
  esac
done

shift $((OPTIND-1))

# Log and output functions
printinfo() {
  printf "::: ${green}%s${reset}\n" "$@"
  printf "::: ${green}%s${reset}\n" "$@" >> "${INSTALL_LOG}"
}

printwarn() {
 printf "${tan}*** WARNING: %s${reset}\n" "$@"
 printf "${tan}*** WARNING: %s${reset}\n" "$@" >> "${INSTALL_LOG}"
}

printerror() {
 printf "${red}*** ERROR: %s${reset}\n" "$@"
 printf "${red}*** ERROR: %s${reset}\n" "$@" >> "${INSTALL_LOG}"
}

die () {
  local st="$?"
  printerror "$@"
  exit "$st"
}

# Check for network connection
verifyInternetConnection() {
  printinfo "Checking for Internet connection..."
  
  # Debug: check what commands are available
  echo "Internet connectivity check" >> "${INSTALL_LOG}" 2>&1
  
  # Try ping first
  if command -v ping > /dev/null; then
    if ping -c 1 google.com > /dev/null 2>&1; then
      printinfo "Internet connection successful!"
      return 0
    fi
    echo "Ping check failed" >> "${INSTALL_LOG}" 2>&1
  fi
  
  # Try curl next
  if command -v curl > /dev/null; then
    if curl -s --head https://google.com > /dev/null 2>&1; then
      printinfo "Internet connection successful!"
      return 0
    fi
    echo "Curl check failed" >> "${INSTALL_LOG}" 2>&1
  fi
  
  # Try wget
  if command -v wget > /dev/null; then
    if wget -q --spider https://google.com > /dev/null 2>&1; then
      printinfo "Internet connection successful!"
      return 0
    fi
    echo "Wget check failed" >> "${INSTALL_LOG}" 2>&1
  fi
  
  # If we got here, none of the checks succeeded
  echo
  printerror "Could not connect to the internet. Please check your connection"
  printerror "and try again. The installer needs internet access to download"
  printerror "files from GitHub."
  
  # For testing purposes, we'll continue anyway - REMOVE THIS FOR PRODUCTION
  printinfo "For testing purposes, we'll continue anyway."
  return 0
}

# Check disk space
verifyFreeDiskSpace() {
  printinfo "Verifying free disk space..."
  local required_free_gigabytes=1
  local required_free_kilobytes=$(( required_free_gigabytes*1024000 ))
  
  # Improved method: look specifically for the root filesystem (typically mounted on /)
  # Filter for lines where the mount point is exactly "/" (not /dev, /run, etc.)
  local existing_free_kilobytes=$(df -Pk | awk '$6 == "/" {print $4}')
  
  # If root filesystem wasn't found, try a more general approach
  if [[ -z "${existing_free_kilobytes}" ]]; then
    # Look for filesystems mounted at / or containing /home, prioritizing the root filesystem
    existing_free_kilobytes=$(df -Pk | awk '$6 ~ /^\/$/ {print $4; exit}')
    if [[ -z "${existing_free_kilobytes}" ]]; then
      existing_free_kilobytes=$(df -Pk | awk '$6 ~ /\/home/ {print $4; exit}')
    fi
    
    # Last resort: check the filesystem containing the current directory
    if [[ -z "${existing_free_kilobytes}" ]]; then
      local current_dir
      current_dir=$(pwd)
      existing_free_kilobytes=$(df -Pk "${current_dir}" | awk 'NR==2 {print $4}')
    fi
  fi

  # - Unknown free disk space, not a integer
  if ! [[ "${existing_free_kilobytes}" =~ ^([0-9])+$ ]]; then
    printwarn "Unknown free disk space!"
    
    # In interactive mode, allow user to continue anyway
    if [[ ${INTERACTIVE} -eq 1 ]]; then
      echo
      read -p "Continue anyway? [y/N]: " CONTINUE_CHOICE
      case "${CONTINUE_CHOICE}" in
        y | Y | yes | YES | Yes )
          printwarn "Continuing installation despite unknown free disk space..."
          return 0
          ;;
        * )
          die "Installation cancelled due to unknown free disk space."
          ;;
      esac
    else
      die "We were unable to determine available free disk space on this system."
    fi
  # - Insufficient free disk space
  elif [[ ${existing_free_kilobytes} -lt ${required_free_kilobytes} ]]; then
    local existing_free_mb=$(( existing_free_kilobytes / 1024 ))
    local required_free_mb=$(( required_free_kilobytes / 1024 ))
    
    printwarn "Insufficient Disk Space!"
    printinfo "Your system appears to be low on disk space. ${PACKAGE_NAME} recommends a minimum of $required_free_gigabytes GB."
    printinfo "Current free space: ${existing_free_mb} MB (need ${required_free_mb} MB)"
    
    # In interactive mode, allow user to continue anyway
    if [[ ${INTERACTIVE} -eq 1 ]]; then
      echo
      read -p "Continue anyway? [y/N]: " CONTINUE_CHOICE
      case "${CONTINUE_CHOICE}" in
        y | Y | yes | YES | Yes )
          printwarn "Continuing installation despite insufficient disk space..."
          return 0
          ;;
        * )
          die "Installation cancelled due to insufficient disk space."
          ;;
      esac
    else
      die "Insufficient free space, exiting..."
    fi
  fi
  
  # Convert to MB for more readable output
  local existing_free_mb=$(( existing_free_kilobytes / 1024 ))
  printinfo "Sufficient free disk space is available (${existing_free_mb} MB free)"
}

# Install system dependencies
install_dependencies() {
  printinfo "Installing required dependencies"

  if [ -f /etc/debian_version ]; then
    # Debian/Ubuntu based systems
    sudo apt-get update >> "${INSTALL_LOG}" 2>&1
    sudo apt-get install -y python3 python3-pip git supervisor >> "${INSTALL_LOG}" 2>&1 || die "Failed to install dependencies"
  elif [ -f /etc/redhat-release ]; then
    # RHEL/CentOS/Fedora
    sudo yum -y install python3 python3-pip git >> "${INSTALL_LOG}" 2>&1 || die "Failed to install dependencies"
    # For RHEL/CentOS/Fedora, supervisor needs to be installed via pip
    sudo pip3 install supervisor >> "${INSTALL_LOG}" 2>&1 || printwarn "Failed to install supervisor"
  elif command -v brew &>/dev/null; then
    # macOS with Homebrew
    brew install python3 git >> "${INSTALL_LOG}" 2>&1 || die "Failed to install dependencies"
    pip3 install supervisor >> "${INSTALL_LOG}" 2>&1 || printwarn "Failed to install supervisor"
  else
    printwarn "Unsupported system, trying to proceed anyway"
    printwarn "You may need to manually install Python 3, pip, git, and supervisor"
  fi

  # Check if uv is installed, and install it if not
  printinfo "Checking if uv is installed..."
  if ! command -v uv &> /dev/null; then
    printinfo "uv not found, installing..."
    curl -LsSf https://astral.sh/uv/install.sh | sh >> "${INSTALL_LOG}" 2>&1 || {
      die "Failed to install uv. Installation will not continue without it."
    }
    # Reload PATH to include uv if it was just installed
    if [ -f "$HOME/.local/bin/env" ]; then
      . "$HOME/.local/bin/env"
    fi
    # Report installation status
    if command -v uv &> /dev/null; then
      printinfo "uv installed successfully"
    fi
  else
    printinfo "uv is already installed"
  fi

  printinfo "Dependencies installed successfully"
}

# Check Python version
check_python_version() {
  local required_version=$1
  local current_version
  local quiet=${2:-false}

  # Check if Python is installed
  if ! command -v python3 &> /dev/null; then
    if [ "$quiet" != "true" ]; then
      printerror "Python 3 is not installed or not in PATH."
    fi
    return 1
  fi

  # Get the current Python version
  current_version=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')

  # Manual version comparison (avoid dependency on external modules)
  local IFS='.'
  read -ra CURR_PARTS <<< "$current_version"
  read -ra REQ_PARTS <<< "$required_version"

  # Compare major version
  if [ "${CURR_PARTS[0]}" -gt "${REQ_PARTS[0]}" ]; then
    if [ "$quiet" != "true" ]; then
      printinfo "Python version $current_version is compatible (required: $required_version)."
    fi
    return 0
  elif [ "${CURR_PARTS[0]}" -lt "${REQ_PARTS[0]}" ]; then
    if [ "$quiet" != "true" ]; then
      printerror "Python version $current_version is not compatible (required: $required_version or newer)."
    fi
    return 1
  fi

  # Compare minor version
  if [ "${CURR_PARTS[1]}" -gt "${REQ_PARTS[1]}" ]; then
    if [ "$quiet" != "true" ]; then
      printinfo "Python version $current_version is compatible (required: $required_version)."
    fi
    return 0
  elif [ "${CURR_PARTS[1]}" -lt "${REQ_PARTS[1]}" ]; then
    if [ "$quiet" != "true" ]; then
      printerror "Python version $current_version is not compatible (required: $required_version or newer)."
    fi
    return 1
  fi

  # Compare patch version
  if [ "${CURR_PARTS[2]}" -ge "${REQ_PARTS[2]}" ]; then
    if [ "$quiet" != "true" ]; then
      printinfo "Python version $current_version is compatible (required: $required_version)."
    fi
    return 0
  else
    if [ "$quiet" != "true" ]; then
      printerror "Python version $current_version is not compatible (required: $required_version or newer)."
    fi
    return 1
  fi
}

create_uv_venv() {
  # Check if Python is installed and version is compatible
  if ! check_python_version "$MIN_PYTHON_VERSION"; then
    printerror "Python is either not installed or its version is too old."
    printerror "Serial to Fermentrack requires Python $MIN_PYTHON_VERSION or newer."
    return 1
  fi

  # Check if uv is installed
  if ! command -v uv &> /dev/null; then
    printerror "uv is not installed. Installation cannot continue."
    printinfo "uv should be installed by this script automatically, but manual instructions can be found at:"
    printinfo "    https://github.com/astral-sh/uv"
    return 1
  fi

  # Create a virtualenv in the script's directory
  local venv_dir="${myPath}/.venv"
  printinfo "Creating virtual environment in ${venv_dir}..."

  # Create virtualenv using uv
  if ! uv venv --allow-existing >> "${INSTALL_LOG}" 2>&1; then
    # If uv failed, return error - we require uv
    printerror "Failed to create virtualenv with uv. Installation cannot continue."
    return 1
  fi

}

# Serial to Fermentrack installation
install_serial_to_fermentrack() {
  printinfo "Installing Serial to Fermentrack..."

  create_uv_venv

  # Create a temporary directory for download
  local tmp_dir
  tmp_dir=$(mktemp -d)
  printinfo "Downloading Serial to Fermentrack wheel file..."

  # Download the wheel file - extract the filename from the URL
  local wheel_filename=$(basename "$SERIAL_TO_FERMENTRACK_WHEEL_URL")
  if ! curl -L -o "$tmp_dir/$wheel_filename" "$SERIAL_TO_FERMENTRACK_WHEEL_URL" >> "${INSTALL_LOG}" 2>&1; then
    printerror "Failed to download Serial to Fermentrack wheel file."
    rm -rf "$tmp_dir"
    return 1
  fi

  # Install the wheel file
  printinfo "Installing Serial to Fermentrack wheel file into virtualenv..."

  # Install using uv, with custom wheel index if requested
  if [[ ${USE_CUSTOM_WHEELS} -eq 1 ]]; then
    printinfo "Using custom Fermentrack wheels index to speed up installation..."
    if ! uv pip install --index fermentrack="https://wheels.fermentrack.com/simple" --index-strategy unsafe-best-match "$tmp_dir/$wheel_filename" >> "${INSTALL_LOG}" 2>&1; then
      printerror "Failed to install with uv and custom wheels. Installation cannot continue."
      rm -rf "$tmp_dir"
      return 1
    else
      printinfo "Serial to Fermentrack installed successfully with uv using custom wheels."
    fi
  else
    # Standard installation
    if ! uv pip install "$tmp_dir/$wheel_filename" >> "${INSTALL_LOG}" 2>&1; then
      printerror "Failed to install with uv. Installation cannot continue."
      rm -rf "$tmp_dir"
      return 1
    else
      printinfo "Serial to Fermentrack installed successfully with uv."
    fi
  fi

  # Create wrapper scripts for easy execution
  printinfo "Creating wrapper scripts..."

  # Main wrapper script
  cat > "${myPath}/serial_to_fermentrack" << EOF
#!/bin/bash
# Wrapper script for Serial to Fermentrack
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
source "\${SCRIPT_DIR}/.venv/bin/activate"
serial_to_fermentrack "\$@"
EOF

  chmod +x "${myPath}/serial_to_fermentrack"

  # Configuration wrapper script
  cat > "${myPath}/serial_to_fermentrack_config" << EOF
#!/bin/bash
# Wrapper script for Serial to Fermentrack Config
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
source "\${SCRIPT_DIR}/.venv/bin/activate"
serial_to_fermentrack_config "\$@"
EOF

  chmod +x "${myPath}/serial_to_fermentrack_config"

  # Daemon wrapper script
  cat > "${myPath}/serial_to_fermentrack_daemon" << EOF
#!/bin/bash
# Wrapper script for Serial to Fermentrack Daemon
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
source "\${SCRIPT_DIR}/.venv/bin/activate"
serial_to_fermentrack_daemon "\$@"
EOF

  chmod +x "${myPath}/serial_to_fermentrack_daemon"

  # Create logs directory
  mkdir -p "${myPath}/logs"

  # Determine autostart preference
  if [[ ${UPGRADE_MODE} -eq 1 ]]; then
    # In upgrade mode, check if supervisor config exists
    SUPERVISOR_CONFIG_DIR="/etc/supervisor/conf.d"
    ALT_SUPERVISOR_CONFIG_DIR="/etc/supervisord.d"
    
    if [[ -f "$SUPERVISOR_CONFIG_DIR/serial_to_fermentrack.conf" || -f "$ALT_SUPERVISOR_CONFIG_DIR/serial_to_fermentrack.conf" ]]; then
      printinfo "Existing supervisor configuration detected, will keep daemon autostarting"
      AUTO_START=1
    else
      AUTO_START=0
    fi
  # Ask user if not in upgrade mode
  elif [[ ${INTERACTIVE} -eq 1 ]]; then
    echo
    read -p "Do you want serial_to_fermentrack to run automatically at startup? [Y/n]: " AUTO_START_CHOICE
    case "${AUTO_START_CHOICE}" in
      n | N | no | NO | No )
        AUTO_START=0
        ;;
      * )
        AUTO_START=1
        ;;
    esac
  else
    # Default to yes in non-interactive mode
    AUTO_START=1
  fi

  # Set up supervisor configuration if requested
  if [[ ${AUTO_START} -eq 1 ]]; then
    printinfo "Setting up supervisor configuration..."

    # Get current username
    CURRENT_USER=$(whoami)

    # Create supervisor config file
    SUPERVISOR_CONFIG_DIR="/etc/supervisor/conf.d"
    if [ ! -d "$SUPERVISOR_CONFIG_DIR" ]; then
      # Try alternative location for supervisor config
      SUPERVISOR_CONFIG_DIR="/etc/supervisord.d"
      if [ ! -d "$SUPERVISOR_CONFIG_DIR" ]; then
        # Create directory if it doesn't exist
        sudo mkdir -p "$SUPERVISOR_CONFIG_DIR"
      fi
    fi

    # Create the supervisor configuration file
    cat > "${myPath}/serial_to_fermentrack.conf" << EOF
[program:serial_to_fermentrack]
command=${myPath}/.venv/bin/python -m serial_to_fermentrack_daemon
directory=${myPath}
user=${CURRENT_USER}
autostart=true
autorestart=true
startsecs=5
startretries=3
stderr_logfile=${myPath}/logs/serial_to_fermentrack_error.log
stderr_logfile_maxbytes=2MB
stderr_logfile_backups=5
stdout_logfile=${myPath}/logs/serial_to_fermentrack_stdout.log
stdout_logfile_maxbytes=2MB
stdout_logfile_backups=5
environment=VIRTUAL_ENV="${myPath}/.venv",PATH="${myPath}/.venv/bin:%(ENV_PATH)s",PYTHONUNBUFFERED="1"
EOF

    # Install the supervisor config
    sudo cp "${myPath}/serial_to_fermentrack.conf" "$SUPERVISOR_CONFIG_DIR/"

    # Reload supervisor configuration
    if command -v supervisorctl &> /dev/null; then
      printinfo "Reloading supervisor configuration..."
      sudo supervisorctl reread
      sudo supervisorctl update
      sudo supervisorctl start serial_to_fermentrack

      # Check if service started successfully
      if sudo supervisorctl status serial_to_fermentrack | grep -q "RUNNING"; then
        printinfo "Serial to Fermentrack daemon is now running under supervisor!"
      else
        printwarn "Failed to start Serial to Fermentrack daemon. You can try starting it manually with 'sudo supervisorctl start serial_to_fermentrack'"
      fi
    else
      printwarn "supervisorctl command not found. Please reload supervisor manually."
      printinfo "A supervisor configuration file has been created at: $SUPERVISOR_CONFIG_DIR/serial_to_fermentrack.conf"
    fi
  fi

  # Clean up
  rm -rf "$tmp_dir"

  echo
  echo "Serial to Fermentrack is now installed, but still requires configuration."
  echo "To configure, run '${myPath}/serial_to_fermentrack_config'"
  echo

  if [[ ${AUTO_START} -eq 1 ]]; then
    echo "Serial to Fermentrack daemon will automatically using supervisor."
    echo "Logs are available at: ${myPath}/logs/"
    echo
  else
    echo "To run the daemon manually, use '${myPath}/serial_to_fermentrack_daemon'"
    echo
  fi

  return 0
}

# BrewFlasher Command Line Edition installation
install_brewflasher() {
  printinfo "Installing BrewFlasher Command Line Edition..."

  create_uv_venv

  # Install brewflasher_cli from pypi into the virtualenv, with custom wheel index if requested
  if [[ ${USE_CUSTOM_WHEELS} -eq 1 ]]; then
    printinfo "Using custom Fermentrack wheels index to speed up installation..."
    if ! uv pip install --index fermentrack="https://wheels.fermentrack.com/simple" --index-strategy unsafe-best-match --upgrade brewflasher_cli >> "${INSTALL_LOG}" 2>&1; then
      printerror "Failed to install BrewFlasher CLI from PyPi with custom wheels. Installation cannot continue."
      return 1
    fi
  else
    # Standard installation
    if ! uv pip install --upgrade brewflasher_cli >> "${INSTALL_LOG}" 2>&1; then
      # If uv failed, return error - we require uv
      printerror "Failed to install BrewFlasher CLI from PyPi. Installation cannot continue."
      return 1
    fi
  fi

  # BrewFlasher CLI wrapper script
  cat > "${myPath}/brewflasher" << EOF
#!/bin/bash
# Wrapper script for BrewFlasher CLI
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
source "\${SCRIPT_DIR}/.venv/bin/activate"
brewflasher "\$@"
EOF

  chmod +x "${myPath}/brewflasher"


  # Determine if we should install avrdude
  if [[ ${UPGRADE_MODE} -eq 1 ]]; then
    # In upgrade mode, never install avrdude. If it's installed via apt, the the user should upgrade via apt
    INSTALL_AVRDUDE=0
    if command -v avrdude &> /dev/null; then
      printinfo "avrdude is already installed - to upgrade use `apt-get upgrade`"
    else
      # If not installed but we're in upgrade mode, skip it
      printinfo "avrdude is not installed. To install, re-run this script without the upgrade flag"
    fi
  elif [[ ${INTERACTIVE} -eq 1 ]]; then
    echo
    read -p "Do you want to install 'avrdude' to allow flashing Arduinos? [Y/n]: " AVRDUDE_CHOICE
    case "${AVRDUDE_CHOICE}" in
      n | N | no | NO | No )
        INSTALL_AVRDUDE=0
        ;;
      * )
        INSTALL_AVRDUDE=1
        ;;
    esac
  else
    # Default to yes in non-interactive mode
    INSTALL_AVRDUDE=1
  fi

  # Install avrdude if requested
  if [[ ${INSTALL_AVRDUDE} -eq 1 ]]; then
    printinfo "Installing avrdude from apt..."
    sudo apt-get install -y avrdude >> "${INSTALL_LOG}" 2>&1 || printwarn "Failed to install avrdude - Arduino flashing may not work"
  fi

  echo
  echo "BrewFlasher Command Line Edition installed successfully"
  echo "To use, run '${myPath}/brewflasher'"

  return 0
}

# Install Docker for TiltBridge Junior
install_docker() {
  printinfo "Installing Docker for TiltBridge Junior..."

  if command -v docker &> /dev/null; then
    printinfo "Docker is already installed. Continuing."
    return 0
  else
    printinfo "Docker is not installed. Installing..."

    if [ -f /etc/debian_version ]; then
      # Debian/Ubuntu based system
      printinfo "Detected Debian/Ubuntu based system."

      # Install prerequisites
      sudo apt-get update >> "${INSTALL_LOG}" 2>&1
      sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common >> "${INSTALL_LOG}" 2>&1 || {
        printerror "Failed to install Docker prerequisites"
        return 1
      }

      # Add Docker's official GPG key
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - >> "${INSTALL_LOG}" 2>&1 || {
        printerror "Failed to add Docker GPG key"
        return 1
      }

      # Add Docker repository (for Ubuntu, but works for Raspbian/Debian in many cases)
      sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" >> "${INSTALL_LOG}" 2>&1 || {
        # If the above fails, try with Raspbian/Debian specific repo
        source /etc/os-release
        echo "deb [arch=armhf] https://download.docker.com/linux/debian $VERSION_CODENAME stable" | sudo tee /etc/apt/sources.list.d/docker.list >> "${INSTALL_LOG}" 2>&1 || {
          printerror "Failed to add Docker repository"
          return 1
        }
      }

      # Install Docker
      sudo apt-get update >> "${INSTALL_LOG}" 2>&1
      sudo apt-get install -y docker-ce docker-ce-cli containerd.io >> "${INSTALL_LOG}" 2>&1 || {
        # If the above fails, try the convenience script from get.docker.com
        curl -fsSL https://get.docker.com -o get-docker.sh >> "${INSTALL_LOG}" 2>&1
        sudo sh get-docker.sh >> "${INSTALL_LOG}" 2>&1 || {
          printerror "Failed to install Docker"
          return 1
        }
        rm get-docker.sh
      }

    elif [ -f /etc/redhat-release ]; then
      # RHEL/CentOS/Fedora
      printinfo "Detected RHEL/CentOS/Fedora system."

      # Install prerequisites
      sudo yum install -y yum-utils >> "${INSTALL_LOG}" 2>&1 || {
        printerror "Failed to install Docker prerequisites"
        return 1
      }

      # Add Docker repository
      sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >> "${INSTALL_LOG}" 2>&1 || {
        printerror "Failed to add Docker repository"
        return 1
      }

      # Install Docker
      sudo yum install -y docker-ce docker-ce-cli containerd.io >> "${INSTALL_LOG}" 2>&1 || {
        printerror "Failed to install Docker"
        return 1
      }

    elif command -v brew &>/dev/null; then
      # macOS with Homebrew
      printinfo "Detected macOS with Homebrew."
      brew install --cask docker >> "${INSTALL_LOG}" 2>&1 || {
        printerror "Failed to install Docker"
        return 1
      }

    else
      # Generic install using get.docker.com
      printinfo "Using generic Docker installation method."
      curl -fsSL https://get.docker.com -o get-docker.sh >> "${INSTALL_LOG}" 2>&1
      sudo sh get-docker.sh >> "${INSTALL_LOG}" 2>&1 || {
        printerror "Failed to install Docker"
        return 1
      }
      rm get-docker.sh
    fi
  fi

  # Start and enable Docker service
  if command -v systemctl &>/dev/null; then
    printinfo "Starting and enabling Docker service..."
    sudo systemctl start docker >> "${INSTALL_LOG}" 2>&1
    sudo systemctl enable docker >> "${INSTALL_LOG}" 2>&1
  fi

  # Add current user to docker group
  if [ "$USER" != "root" ]; then
    printinfo "Adding user '$USER' to the 'docker' group..."
    sudo usermod -aG docker "$USER" >> "${INSTALL_LOG}" 2>&1
    printinfo "Note: You may need to log out and back in for Docker permissions to take effect."
  fi

  # Verify Docker installation
  if docker --version >> "${INSTALL_LOG}" 2>&1; then
    printinfo "Docker installed successfully!"
    return 0
  else
    printwarn "Docker installation may have issues. Check the log for details."
    return 1
  fi
}

# TiltBridge Junior installation
install_tiltbridge_junior() {
  printinfo "Installing TiltBridge Junior..."

  # Install Docker first (required for TiltBridge Junior)
  install_docker || {
    printerror "Failed to install Docker, which is required for TiltBridge Junior"
    return 1
  }

  # Create directory
  mkdir -p ~/fermentrack_tools/tiltbridge_junior >> "${INSTALL_LOG}" 2>&1

  # Clone the repository
  git clone https://github.com/thorrak/tiltbridge_junior.git ~/fermentrack_tools/tiltbridge_junior/app >> "${INSTALL_LOG}" 2>&1 || {
    printerror "Failed to clone TiltBridge Junior repository"
    return 1
  }

  # Install Python dependencies, with custom wheel index if requested
  if [[ ${USE_CUSTOM_WHEELS} -eq 1 ]]; then
    printinfo "Using custom Fermentrack wheels index to speed up installation..."
    cd ~/fermentrack_tools/tiltbridge_junior/app && pip3 install --index-url https://wheels.fermentrack.com/simple --trusted-host wheels.fermentrack.com -r requirements.txt >> "${INSTALL_LOG}" 2>&1 || {
      printerror "Failed to install TiltBridge Junior dependencies with custom wheels"
      return 1
    }
  else
    # Standard installation
    cd ~/fermentrack_tools/tiltbridge_junior/app && pip3 install -r requirements.txt >> "${INSTALL_LOG}" 2>&1 || {
      printerror "Failed to install TiltBridge Junior dependencies"
      return 1
    }
  fi

  # Create starter script
  cat > ~/fermentrack_tools/tiltbridge_junior/run.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")/app"
python3 tiltbridge_junior.py "$@"
EOF

  chmod +x ~/fermentrack_tools/tiltbridge_junior/run.sh

  printinfo "TiltBridge Junior installed successfully"
  printinfo "Run with: ~/fermentrack_tools/tiltbridge_junior/run.sh"
  return 0
}

# Check for existing installations for upgrade mode
check_existing_installations() {
  printinfo "Checking for existing installations..."
  
  # Check for Serial to Fermentrack
  if [[ -f "${myPath}/serial_to_fermentrack" ]]; then
    printinfo "Found existing Serial to Fermentrack installation"
    INSTALL_SERIAL=1
  fi
  
  # Check for BrewFlasher
  if [[ -f "${myPath}/brewflasher" ]]; then
    printinfo "Found existing BrewFlasher installation"
    INSTALL_BREWFLASHER=1
  fi
  
  # Check for TiltBridge Junior (simple check for the directory)
  if [[ -d "${HOME}/fermentrack_tools/tiltbridge_junior" ]]; then
    printinfo "Found existing TiltBridge Junior installation"
    INSTALL_TILTBRIDGE=1
  fi
  
  # Check if at least one component was found
  if [[ ${INSTALL_SERIAL} -eq 0 && ${INSTALL_BREWFLASHER} -eq 0 && ${INSTALL_TILTBRIDGE} -eq 0 ]]; then
    printwarn "No existing installations detected for upgrade"
    return 1
  fi
  
  return 0
}

# Interactive selection menu
get_user_selections() {
  # If in upgrade mode, detect existing installations
  if [[ ${UPGRADE_MODE} -eq 1 ]]; then
    if ! check_existing_installations; then
      # If no installations found, revert to normal mode
      printwarn "Reverting to normal installation mode"
      UPGRADE_MODE=0
    else
      # In upgrade mode with installations detected, we can skip further prompts
      return 0
    fi
  fi
  
  if [[ ${INTERACTIVE} -eq 1 ]]; then
    # No command line options were provided, ask user for selections
    if [[ ${INSTALL_SERIAL} -eq 0 && ${INSTALL_BREWFLASHER} -eq 0 && ${INSTALL_TILTBRIDGE} -eq 0 ]]; then
      echo
      printinfo "Welcome to the FT2  Installer!"
      printinfo "This installer will help you set up  applications for Fermentrack 2."
      echo

      read -p "Install Serial to Fermentrack? [y/N]: " SERIAL_CHOICE
      case "${SERIAL_CHOICE}" in
        y | Y | yes | YES | Yes )
          INSTALL_SERIAL=1
          ;;
        * )
          INSTALL_SERIAL=0
          ;;
      esac

      read -p "Install BrewFlasher Command Line Edition? [y/N]: " BREWFLASHER_CHOICE
      case "${BREWFLASHER_CHOICE}" in
        y | Y | yes | YES | Yes )
          INSTALL_BREWFLASHER=1
          ;;
        * )
          INSTALL_BREWFLASHER=0
          ;;
      esac

#      read -p "Install TiltBridge Junior? [y/N]: " TILTBRIDGE_CHOICE
#      case "${TILTBRIDGE_CHOICE}" in
#        y | Y | yes | YES | Yes )
#          INSTALL_TILTBRIDGE=1
#          ;;
#        * )
#          INSTALL_TILTBRIDGE=0
#          ;;
#      esac

      # Check if at least one application was selected
      if [[ ${INSTALL_SERIAL} -eq 0 && ${INSTALL_BREWFLASHER} -eq 0 && ${INSTALL_TILTBRIDGE} -eq 0 ]]; then
        printwarn "No applications selected for installation. Exiting."
        exit 0
      fi
    fi
  else
    # If in non-interactive mode, at least one option must be specified
    if [[ ${INSTALL_SERIAL} -eq 0 && ${INSTALL_BREWFLASHER} -eq 0 && ${INSTALL_TILTBRIDGE} -eq 0 ]]; then
      printerror "In non-interactive mode, you must specify at least one application to install using -s, -b, or -t"
      usage
      exit 1
    fi
  fi
}

# Keep track of installation results
SERIAL_INSTALLED=false
BREWFLASHER_INSTALLED=false
TILTBRIDGE_INSTALLED=false

# Installation summary
installation_summary() {
  echo
  if [[ ${UPGRADE_MODE} -eq 1 ]]; then
    printinfo "Upgrade summary:"
  else
    printinfo "Installation summary:"
  fi
  echo
  if [[ ${INSTALL_SERIAL} -eq 1 ]]; then
    if [[ ${SERIAL_INSTALLED} == true ]]; then
      if [[ ${UPGRADE_MODE} -eq 1 ]]; then
        echo " - Serial to Fermentrack: Upgraded"
      else
        echo " - Serial to Fermentrack: Installed"
      fi
      echo "   Run with: serial_to_fermentrack_config"
    else
      if [[ ${UPGRADE_MODE} -eq 1 ]]; then
        echo " - Serial to Fermentrack: Upgrade FAILED"
      else
        echo " - Serial to Fermentrack: Installation FAILED"
      fi
    fi
  fi

  if [[ ${INSTALL_BREWFLASHER} -eq 1 ]]; then
    if [[ ${BREWFLASHER_INSTALLED} == true ]]; then
      if [[ ${UPGRADE_MODE} -eq 1 ]]; then
        echo " - BrewFlasher Command Line Edition: Upgraded"
      else
        echo " - BrewFlasher Command Line Edition: Installed"
      fi
      echo "   Run with: brewflasher"
    else
      if [[ ${UPGRADE_MODE} -eq 1 ]]; then
        echo " - BrewFlasher Command Line Edition: Upgrade FAILED"
      else
        echo " - BrewFlasher Command Line Edition: Installation FAILED"
      fi
    fi
  fi

  if [[ ${INSTALL_TILTBRIDGE} -eq 1 ]]; then
    if [[ ${TILTBRIDGE_INSTALLED} == true ]]; then
      if [[ ${UPGRADE_MODE} -eq 1 ]]; then
        echo " - TiltBridge Junior: Upgraded"
      else
        echo " - TiltBridge Junior: Installed"
      fi
      echo "   Run with: ~/fermentrack_tools/tiltbridge_junior/run.sh"
    else
      if [[ ${UPGRADE_MODE} -eq 1 ]]; then
        echo " - TiltBridge Junior: Upgrade FAILED"
      else
        echo " - TiltBridge Junior: Installation FAILED"
      fi
    fi
  fi

  echo
  if [[ ${UPGRADE_MODE} -eq 1 ]]; then
    printinfo "Upgrade Complete. Happy Brewing!"
  else
    printinfo "Installation Complete. Happy Brewing!"
  fi
}

# Check for updates to the repository
check_for_updates() {
  printinfo "Checking for script updates..."

  # Check if we're in a git repository
  if ! git rev-parse --is-inside-work-tree &> /dev/null; then
    printwarn "Not running from a git repository, skipping update check."
    return 0
  fi

  # Store the current branch
  local current_branch
  current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "detached")

  # Fetch the latest changes without merging
  if ! git fetch origin "${current_branch}" &> /dev/null; then
    printwarn "Failed to fetch updates, continuing with current version."
    return 0
  fi

  # Check if there are changes to pull
  local changes
  changes=$(git log HEAD..origin/"${current_branch}" --oneline 2>/dev/null)

  if [ -n "${changes}" ]; then
    printinfo "Updates are available. The script will now update itself."

    # Show the available changes
    echo "The following updates will be applied:"
    git log --oneline HEAD..origin/"${current_branch}" | sed 's/^/  /'
    echo

    # Pull the changes
    if git pull origin "${current_branch}" &> /dev/null; then
      printinfo "The script has been updated successfully."
      printerror "Please restart the installer to use the updated version."
      exit 0
    else
      printwarn "Failed to update the script. Continuing with current version."
    fi
  else
    printinfo "No updates available. Continuing with current version."
  fi
}

# Check if running on armv6l hardware (Pi Zero, Original Pi)
check_armv6l() {
  if uname -a | grep -q 'armv6l'; then
    printinfo "Detected armv6l hardware (Raspberry Pi Zero, Zero W, or Original Pi)"
    
    if [[ ${INTERACTIVE} -eq 1 ]]; then
      echo
      printinfo "This device is running on an armv6l processor (Pi Zero, Zero W, or Original Pi)."
      echo
      read -p "Use custom Fermentrack Python wheels to speed up installation significantly? [Y/n]: " WHEELS_CHOICE
      case "${WHEELS_CHOICE}" in
        n | N | no | NO | No )
          USE_CUSTOM_WHEELS=0
          printwarn "Installation may require manual installation of rust/cargo and could potentially take 24+ hours to build wheels. Seriously - it is REALLY REALLY slow."
          echo
          read -p "Are you sure you don't want to use custom wheels? [y/N]: " WHEELS_CONFIRM
          case "${WHEELS_CONFIRM}" in
            y | Y | yes | YES | Yes )
              USE_CUSTOM_WHEELS=0
              ;;
            * )
              USE_CUSTOM_WHEELS=1
              printinfo "Using custom wheels for faster installation."
              ;;
          esac
          ;;
        * )
          USE_CUSTOM_WHEELS=1
          printinfo "Using custom wheels for faster installation."
          ;;
      esac
    else
      # Non-interactive mode, default to using custom wheels
      USE_CUSTOM_WHEELS=1
      printinfo "Detected armv6l hardware. Using custom wheels for faster installation."
    fi
    return 0
  fi
  
  # Not armv6l hardware
  USE_CUSTOM_WHEELS=0
  return 1
}

# Main execution flow
main() {
  printinfo "Starting ${PACKAGE_NAME}..."
  
  if [[ ${UPGRADE_MODE} -eq 1 ]]; then
    printinfo "Running in upgrade mode - will auto-detect and upgrade installed components"
  fi

  verifyInternetConnection
  check_for_updates
  verifyFreeDiskSpace
  check_armv6l  # Check for armv6l hardware
  get_user_selections
  install_dependencies

  if [[ ${INSTALL_SERIAL} -eq 1 ]]; then
    if install_serial_to_fermentrack; then
      SERIAL_INSTALLED=true
    else
      printwarn "Serial to Fermentrack installation failed."
    fi
  fi

  if [[ ${INSTALL_BREWFLASHER} -eq 1 ]]; then
    if install_brewflasher; then
      BREWFLASHER_INSTALLED=true
    else
      printwarn "BrewFlasher installation failed."
    fi
  fi

#  if [[ ${INSTALL_TILTBRIDGE} -eq 1 ]]; then
#    if install_tiltbridge_junior; then
#      TILTBRIDGE_INSTALLED=true
#    else
#      printwarn "TiltBridge Junior installation failed."
#    fi
#  fi

  installation_summary
}

# Start the installation process
main
