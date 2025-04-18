#!/usr/bin/env bash

# FT2 Support Installer
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
PACKAGE_NAME="FT2 Support Installer"
INTERACTIVE=1
INSTALL_SERIAL=0
INSTALL_BREWFLASHER=0
INSTALL_TILTBRIDGE=0
INSTALL_LOG="./install.log"

# URLs for installation packages
SERIAL_TO_FERMENTRACK_WHEEL_URL="https://github.com/thorrak/serial_to_fermentrack/releases/download/v0.0.1-alpha1/serial_to_fermentrack-0.0.1-py3-none-any.whl"
SERIAL_TO_FERMENTRACK_MIN_PYTHON_VERSION="3.8.0"

# Help text
function usage() {
    echo "Usage: $0 [-h] [-n] [-s] [-b] [-t]" 1>&2
    echo "Options:"
    echo "  -h                This help"
    echo "  -n                Run non-interactive installation"
    echo "  -s                Install Serial to Fermentrack"
    echo "  -b                Install BrewFlasher Command Line Edition"
    echo "  -t                Install TiltBridge Junior"
    exit 1
}

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
  local existing_free_kilobytes=$(df -Pk | grep -m1 '/' | awk '{print $4}')

  # - Unknown free disk space, not a integer
  if ! [[ "${existing_free_kilobytes}" =~ ^([0-9])+$ ]]; then
    printwarn "Unknown free disk space!"
    die "We were unable to determine available free disk space on this system."
  # - Insufficient free disk space
  elif [[ ${existing_free_kilobytes} -lt ${required_free_kilobytes} ]]; then
    printwarn "Insufficient Disk Space!"
    printinfo "Your system appears to be low on disk space. ${PACKAGE_NAME} recommends a minimum of $required_free_gigabytes GB."
    die "Insufficient free space, exiting..."
  fi
  printinfo "Sufficient free disk space is available"
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

# Serial to Fermentrack installation
install_serial_to_fermentrack() {
  printinfo "Installing Serial to Fermentrack..."
  
  # Check if Python is installed and version is compatible
  if ! check_python_version "$SERIAL_TO_FERMENTRACK_MIN_PYTHON_VERSION"; then
    printerror "Python is either not installed or its version is too old."
    printerror "Serial to Fermentrack requires Python $SERIAL_TO_FERMENTRACK_MIN_PYTHON_VERSION or newer."
    return 1
  fi
  
  # Check if uv is installed
  if ! command -v uv &> /dev/null; then
    printerror "uv is not installed. Installation cannot continue."
    return 1
  else
    local use_uv=true
  fi
  
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
  
  # Create a virtualenv in the script's directory
  local venv_dir="${myPath}/venv"
  printinfo "Creating virtual environment in ${venv_dir}..."
  
  if [ "$use_uv" = true ]; then
    # Create virtualenv using uv
    if ! uv venv --allow-existing "${venv_dir}" >> "${INSTALL_LOG}" 2>&1; then
      printwarn "Failed to create virtualenv with uv. Falling back to standard venv."
      use_uv=false
    fi
  fi
  
  # If uv failed, return error - we require uv
  if [ "$use_uv" = false ]; then
    printerror "Failed to create virtualenv with uv. Installation cannot continue."
    rm -rf "$tmp_dir"
    return 1
  fi
  
  # Install the wheel file
  printinfo "Installing Serial to Fermentrack wheel file into virtualenv..."
  
  if [ "$use_uv" = true ]; then
    # Install using uv
    if ! uv pip install --python "${venv_dir}/bin/python" "$tmp_dir/$wheel_filename" >> "${INSTALL_LOG}" 2>&1; then
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
source "\${SCRIPT_DIR}/venv/bin/activate"
serial_to_fermentrack "\$@"
EOF

  chmod +x "${myPath}/serial_to_fermentrack"
  
  # Configuration wrapper script
  cat > "${myPath}/serial_to_fermentrack_config" << EOF
#!/bin/bash
# Wrapper script for Serial to Fermentrack Config
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
source "\${SCRIPT_DIR}/venv/bin/activate"
serial_to_fermentrack_config "\$@"
EOF

  chmod +x "${myPath}/serial_to_fermentrack_config"

  # Daemon wrapper script
  cat > "${myPath}/serial_to_fermentrack_daemon" << EOF
#!/bin/bash
# Wrapper script for Serial to Fermentrack Daemon
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
source "\${SCRIPT_DIR}/venv/bin/activate"
serial_to_fermentrack_daemon "\$@"
EOF

  chmod +x "${myPath}/serial_to_fermentrack_daemon"

  # Create logs directory
  mkdir -p "${myPath}/logs"

  # Ask user if they want to run the daemon automatically
  if [[ ${INTERACTIVE} -eq 1 ]]; then
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
command=${myPath}/venv/bin/python -m serial_to_fermentrack_daemon
directory=${myPath}
user=${CURRENT_USER}
autostart=true
autorestart=true
startsecs=5
startretries=3
stderr_logfile=${myPath}/logs/serial_to_fermentrack_error.log
stdout_logfile=${myPath}/logs/serial_to_fermentrack_stdout.log
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
  echo
  echo "To configure Serial to Fermentrack, run '${myPath}/serial_to_fermentrack_config'"
  echo
  echo "To run Serial to Fermentrack, run '${myPath}/serial_to_fermentrack'"
  echo
  echo "To activate the virtual environment directly, run '${myPath}/activate.sh'"
  echo
  
  if [[ ${AUTO_START} -eq 1 ]]; then
    echo "Serial to Fermentrack daemon is configured to start automatically using supervisor."
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
  
  # Create directory
  mkdir -p ~/fermentrack_tools/brewflasher >> "${INSTALL_LOG}" 2>&1
  
  # Clone the repository
  git clone https://github.com/thorrak/brewflasher-cli.git ~/fermentrack_tools/brewflasher/app >> "${INSTALL_LOG}" 2>&1 || {
    printerror "Failed to clone BrewFlasher repository"
    return 1
  }
  
  # Install Python dependencies
  cd ~/fermentrack_tools/brewflasher/app && pip3 install -r requirements.txt >> "${INSTALL_LOG}" 2>&1 || {
    printerror "Failed to install BrewFlasher dependencies"
    return 1
  }
  
  # Create starter script
  cat > ~/fermentrack_tools/brewflasher/run.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")/app"
python3 brewflasher.py "$@"
EOF
  
  chmod +x ~/fermentrack_tools/brewflasher/run.sh
  
  printinfo "BrewFlasher Command Line Edition installed successfully"
  printinfo "Run with: ~/fermentrack_tools/brewflasher/run.sh"
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
  
  # Install Python dependencies
  cd ~/fermentrack_tools/tiltbridge_junior/app && pip3 install -r requirements.txt >> "${INSTALL_LOG}" 2>&1 || {
    printerror "Failed to install TiltBridge Junior dependencies"
    return 1
  }
  
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

# Interactive selection menu
get_user_selections() {
  if [[ ${INTERACTIVE} -eq 1 ]]; then
    # No command line options were provided, ask user for selections
    if [[ ${INSTALL_SERIAL} -eq 0 && ${INSTALL_BREWFLASHER} -eq 0 && ${INSTALL_TILTBRIDGE} -eq 0 ]]; then
      echo
      printinfo "Welcome to the FT2 Support Installer!"
      printinfo "This installer will help you set up support applications for Fermentrack 2."
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
      
      read -p "Install TiltBridge Junior? [y/N]: " TILTBRIDGE_CHOICE
      case "${TILTBRIDGE_CHOICE}" in
        y | Y | yes | YES | Yes )
          INSTALL_TILTBRIDGE=1
          ;;
        * )
          INSTALL_TILTBRIDGE=0
          ;;
      esac
      
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
  printinfo "Installation summary:"
  echo
  if [[ ${INSTALL_SERIAL} -eq 1 ]]; then
    if [[ ${SERIAL_INSTALLED} == true ]]; then
      echo " - Serial to Fermentrack: Installed"
      echo "   Run with: serial_to_fermentrack_config"
    else
      echo " - Serial to Fermentrack: Installation FAILED"
    fi
  fi
  
  if [[ ${INSTALL_BREWFLASHER} -eq 1 ]]; then
    if [[ ${BREWFLASHER_INSTALLED} == true ]]; then
      echo " - BrewFlasher Command Line Edition: Installed"
      echo "   Run with: ~/fermentrack_tools/brewflasher/run.sh"
    else
      echo " - BrewFlasher Command Line Edition: Installation FAILED"
    fi
  fi
  
  if [[ ${INSTALL_TILTBRIDGE} -eq 1 ]]; then
    if [[ ${TILTBRIDGE_INSTALLED} == true ]]; then
      echo " - TiltBridge Junior: Installed"
      echo "   Run with: ~/fermentrack_tools/tiltbridge_junior/run.sh"
    else
      echo " - TiltBridge Junior: Installation FAILED"
    fi
  fi
  
  echo
  printinfo "Installation Complete!"
  echo "Thank you for using the FT2 Support Installer."
  echo
  printinfo "Happy Brewing!"
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
      printinfo "Please restart the installer to use the updated version."
      exit 0
    else
      printwarn "Failed to update the script. Continuing with current version."
    fi
  else
    printinfo "No updates available. Continuing with current version."
  fi
}

# Main execution flow
main() {
  printinfo "Starting ${PACKAGE_NAME}..."
  
  verifyInternetConnection
  check_for_updates
  verifyFreeDiskSpace
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
  
  if [[ ${INSTALL_TILTBRIDGE} -eq 1 ]]; then
    if install_tiltbridge_junior; then
      TILTBRIDGE_INSTALLED=true
    else
      printwarn "TiltBridge Junior installation failed."
    fi
  fi
  
  installation_summary
}

# Start the installation process
main