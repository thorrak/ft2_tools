#!/usr/bin/env bash

# FT2 Support Installer - Bootstrap Script
# This script is designed to be run directly from the internet to start the installation process
# Example: curl -L https://raw.githubusercontent.com/thorrak/ft2_support_installer/main/install.sh | bash

# Colors for terminal output
green=$(tput setaf 76)
red=$(tput setaf 1)
tan=$(tput setaf 3)
reset=$(tput sgr0)

# Repository URL
REPO_URL="https://github.com/thorrak/ft2_support_installer.git"
REPO_NAME="ft2_support_installer"

# Print functions
print_info() {
  printf "::: ${green}%s${reset}\n" "$@"
}

print_warn() {
  printf "${tan}*** WARNING: %s${reset}\n" "$@"
}

print_error() {
  printf "${red}*** ERROR: %s${reset}\n" "$@"
}

die() {
  local st="$?"
  print_error "$@"
  exit "$st"
}

# Check and install git if needed
install_git() {
  print_info "Checking if git is installed..."
  
  if command -v git &> /dev/null; then
    print_info "git is already installed."
    return 0
  fi
  
  print_info "git not found, installing..."
  
  if [ -f /etc/debian_version ]; then
    # Debian/Ubuntu based systems
    print_info "Detected Debian/Ubuntu based system."
    sudo apt-get update
    sudo apt-get install -y git || die "Failed to install git"
  elif command -v brew &>/dev/null; then
    # macOS with Homebrew
    print_info "Detected macOS with Homebrew."
    brew install git || die "Failed to install git"
  elif [ -f /etc/redhat-release ]; then
    # RHEL/CentOS/Fedora
    print_info "Detected RHEL/CentOS/Fedora system."
    sudo yum -y install git || die "Failed to install git"
  else
    print_warn "Unsupported system. Please install git manually and run this script again."
    die "Cannot continue without git."
  fi
  
  print_info "git installed successfully."
}

# Check if repository exists and clone/update as needed
setup_repo() {
  # Check if we're already in the repo directory
  if [ -d ".git" ] && git remote -v | grep -q "${REPO_URL}"; then
    print_info "Already in the repository directory. Updating..."
    git pull || print_warn "Failed to update repository, continuing with existing files"
    return 0
  fi
  
  # Check if repo exists in the ft2_support_installer subdirectory
  if [ -d "${REPO_NAME}/.git" ] && (cd "${REPO_NAME}" && git remote -v | grep -q "${REPO_URL}"); then
    print_info "Repository already exists in ${REPO_NAME} directory. Updating..."
    cd "${REPO_NAME}" || die "Failed to change to ${REPO_NAME} directory"
    git pull || print_warn "Failed to update repository, continuing with existing files"
    return 0
  fi
  
  # Repository doesn't exist, clone it
  print_info "Cloning repository..."
  git clone "${REPO_URL}" "${REPO_NAME}" || die "Failed to clone repository"
  cd "${REPO_NAME}" || die "Failed to change to repository directory"
  print_info "Repository cloned successfully."
}

# Main execution flow
main() {
  print_info "Starting FT2 Support Installer bootstrap..."
  
  # Install git if needed
  install_git
  
  # Setup repository
  setup_repo
  
  # Make sure the installer script is executable
  chmod +x ./ft2_support_installer.sh
  
  print_info "Launching FT2 Support Installer..."
  print_info "====================================="
  
  # Launch the main installer script interactively
  ./ft2_support_installer.sh
}

# Start the installation process
main