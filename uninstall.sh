#!/usr/bin/env bash

# FT2 Local Tools Uninstaller
# This script uninstalls support applications for Fermentrack 2:
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
PACKAGE_NAME="FT2 Local Tools Uninstaller"
INTERACTIVE=1
UNINSTALL_SERIAL=0
UNINSTALL_BREWFLASHER=0
UNINSTALL_TILTBRIDGE=0
UNINSTALL_LOG="./uninstall.log"

# Help text
function usage() {
    echo "Usage: $0 [-h] [-n] [-s] [-b] [-t]" 1>&2
    echo "Options:"
    echo "  -h                This help"
    echo "  -n                Run non-interactive uninstallation"
    echo "  -s                Uninstall Serial to Fermentrack"
    echo "  -b                Uninstall BrewFlasher Command Line Edition"
    echo "  -t                Uninstall TiltBridge Junior"
    exit 1
}

while getopts "nhsbt" opt; do
  case ${opt} in
    n)
      INTERACTIVE=0  # Silent/Non-interactive Mode
      ;;
    s)
      UNINSTALL_SERIAL=1  # Uninstall Serial to Fermentrack
      ;;
    b)
      UNINSTALL_BREWFLASHER=1  # Uninstall BrewFlasher Command Line Edition
      ;;
    t)
      UNINSTALL_TILTBRIDGE=1  # Uninstall TiltBridge Junior
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
  printf "::: ${green}%s${reset}\n" "$@" >> "${UNINSTALL_LOG}"
}

printwarn() {
 printf "${tan}*** WARNING: %s${reset}\n" "$@"
 printf "${tan}*** WARNING: %s${reset}\n" "$@" >> "${UNINSTALL_LOG}"
}

printerror() {
 printf "${red}*** ERROR: %s${reset}\n" "$@"
 printf "${red}*** ERROR: %s${reset}\n" "$@" >> "${UNINSTALL_LOG}"
}

die () {
  local st="$?"
  printerror "$@"
  exit "$st"
}

# Check for existing installations
check_existing_installations() {
  printinfo "Checking for existing installations..."
  
  # Check for Serial to Fermentrack
  if [[ -f "${myPath}/serial_to_fermentrack" ]]; then
    printinfo "Found existing Serial to Fermentrack installation"
    HAS_SERIAL=1
  else
    HAS_SERIAL=0
  fi
  
  # Check for BrewFlasher
  if [[ -f "${myPath}/brewflasher" ]]; then
    printinfo "Found existing BrewFlasher installation"
    HAS_BREWFLASHER=1
  else
    HAS_BREWFLASHER=0
  fi
  
  # Check for TiltBridge Junior (simple check for the directory)
  if [[ -d "${HOME}/fermentrack_tools/tiltbridge_junior" ]]; then
    printinfo "Found existing TiltBridge Junior installation"
    HAS_TILTBRIDGE=1
  else
    HAS_TILTBRIDGE=0
  fi
  
  # Check if at least one component was found
  if [[ ${HAS_SERIAL} -eq 0 && ${HAS_BREWFLASHER} -eq 0 && ${HAS_TILTBRIDGE} -eq 0 ]]; then
    printwarn "No existing installations detected"
    return 1
  fi
  
  return 0
}

# Interactive selection menu
get_user_selections() {
  # First, check what's installed
  check_existing_installations
  
  if [[ ${INTERACTIVE} -eq 1 ]]; then
    # No command line options were provided, ask user for selections
    if [[ ${UNINSTALL_SERIAL} -eq 0 && ${UNINSTALL_BREWFLASHER} -eq 0 && ${UNINSTALL_TILTBRIDGE} -eq 0 ]]; then
      echo
      printinfo "Welcome to the FT2 Tools Uninstaller!"
      printinfo "This uninstaller will help you remove FT2 support applications."
      echo
      
      if [[ ${HAS_SERIAL} -eq 1 ]]; then
        read -p "Uninstall Serial to Fermentrack? [y/N]: " SERIAL_CHOICE
        case "${SERIAL_CHOICE}" in
          y | Y | yes | YES | Yes )
            UNINSTALL_SERIAL=1
            ;;
          * )
            UNINSTALL_SERIAL=0
            ;;
        esac
      fi

      if [[ ${HAS_BREWFLASHER} -eq 1 ]]; then
        read -p "Uninstall BrewFlasher Command Line Edition? [y/N]: " BREWFLASHER_CHOICE
        case "${BREWFLASHER_CHOICE}" in
          y | Y | yes | YES | Yes )
            UNINSTALL_BREWFLASHER=1
            ;;
          * )
            UNINSTALL_BREWFLASHER=0
            ;;
        esac
      fi

      if [[ ${HAS_TILTBRIDGE} -eq 1 ]]; then
        read -p "Uninstall TiltBridge Junior? [y/N]: " TILTBRIDGE_CHOICE
        case "${TILTBRIDGE_CHOICE}" in
          y | Y | yes | YES | Yes )
            UNINSTALL_TILTBRIDGE=1
            ;;
          * )
            UNINSTALL_TILTBRIDGE=0
            ;;
        esac
      fi

      # Check if at least one application was selected
      if [[ ${UNINSTALL_SERIAL} -eq 0 && ${UNINSTALL_BREWFLASHER} -eq 0 && ${UNINSTALL_TILTBRIDGE} -eq 0 ]]; then
        printwarn "No applications selected for uninstallation. Exiting."
        exit 0
      fi
    else
      # Command line options were provided, but make sure they're actually installed
      if [[ ${UNINSTALL_SERIAL} -eq 1 && ${HAS_SERIAL} -eq 0 ]]; then
        printwarn "Serial to Fermentrack not found, skipping uninstallation"
        UNINSTALL_SERIAL=0
      fi
      
      if [[ ${UNINSTALL_BREWFLASHER} -eq 1 && ${HAS_BREWFLASHER} -eq 0 ]]; then
        printwarn "BrewFlasher not found, skipping uninstallation"
        UNINSTALL_BREWFLASHER=0
      fi
      
      if [[ ${UNINSTALL_TILTBRIDGE} -eq 1 && ${HAS_TILTBRIDGE} -eq 0 ]]; then
        printwarn "TiltBridge Junior not found, skipping uninstallation"
        UNINSTALL_TILTBRIDGE=0
      fi
    fi
  else
    # In non-interactive mode, at least one option must be specified
    if [[ ${UNINSTALL_SERIAL} -eq 0 && ${UNINSTALL_BREWFLASHER} -eq 0 && ${UNINSTALL_TILTBRIDGE} -eq 0 ]]; then
      printerror "In non-interactive mode, you must specify at least one application to uninstall using -s, -b, or -t"
      usage
      exit 1
    fi
    
    # Make sure specified applications are actually installed
    if [[ ${UNINSTALL_SERIAL} -eq 1 && ${HAS_SERIAL} -eq 0 ]]; then
      printwarn "Serial to Fermentrack not found, skipping uninstallation"
      UNINSTALL_SERIAL=0
    fi
    
    if [[ ${UNINSTALL_BREWFLASHER} -eq 1 && ${HAS_BREWFLASHER} -eq 0 ]]; then
      printwarn "BrewFlasher not found, skipping uninstallation"
      UNINSTALL_BREWFLASHER=0
    fi
    
    if [[ ${UNINSTALL_TILTBRIDGE} -eq 1 && ${HAS_TILTBRIDGE} -eq 0 ]]; then
      printwarn "TiltBridge Junior not found, skipping uninstallation"
      UNINSTALL_TILTBRIDGE=0
    fi
  fi
}

# Serial to Fermentrack uninstallation
uninstall_serial_to_fermentrack() {
  printinfo "Uninstalling Serial to Fermentrack..."
  
  # Stop and remove supervisor service if it exists
  SUPERVISOR_CONFIG_DIR="/etc/supervisor/conf.d"
  ALT_SUPERVISOR_CONFIG_DIR="/etc/supervisord.d"
  
  if [[ -f "$SUPERVISOR_CONFIG_DIR/serial_to_fermentrack.conf" ]]; then
    printinfo "Stopping and removing supervisor service..."
    sudo supervisorctl stop serial_to_fermentrack >> "${UNINSTALL_LOG}" 2>&1 || printwarn "Failed to stop supervisor service"
    sudo rm "$SUPERVISOR_CONFIG_DIR/serial_to_fermentrack.conf" >> "${UNINSTALL_LOG}" 2>&1 || printwarn "Failed to remove supervisor config"
    sudo supervisorctl reread >> "${UNINSTALL_LOG}" 2>&1
    sudo supervisorctl update >> "${UNINSTALL_LOG}" 2>&1
  elif [[ -f "$ALT_SUPERVISOR_CONFIG_DIR/serial_to_fermentrack.conf" ]]; then
    printinfo "Stopping and removing supervisor service..."
    sudo supervisorctl stop serial_to_fermentrack >> "${UNINSTALL_LOG}" 2>&1 || printwarn "Failed to stop supervisor service"
    sudo rm "$ALT_SUPERVISOR_CONFIG_DIR/serial_to_fermentrack.conf" >> "${UNINSTALL_LOG}" 2>&1 || printwarn "Failed to remove supervisor config"
    sudo supervisorctl reread >> "${UNINSTALL_LOG}" 2>&1
    sudo supervisorctl update >> "${UNINSTALL_LOG}" 2>&1
  fi
  
  # Remove local supervisor config file if it exists
  if [[ -f "${myPath}/serial_to_fermentrack.conf" ]]; then
    rm "${myPath}/serial_to_fermentrack.conf" >> "${UNINSTALL_LOG}" 2>&1 || printwarn "Failed to remove local supervisor config"
  fi
  
  # Remove wrapper scripts
  if [[ -f "${myPath}/serial_to_fermentrack" ]]; then
    rm "${myPath}/serial_to_fermentrack" >> "${UNINSTALL_LOG}" 2>&1 || printwarn "Failed to remove serial_to_fermentrack script"
  fi
  
  if [[ -f "${myPath}/serial_to_fermentrack_config" ]]; then
    rm "${myPath}/serial_to_fermentrack_config" >> "${UNINSTALL_LOG}" 2>&1 || printwarn "Failed to remove serial_to_fermentrack_config script"
  fi
  
  if [[ -f "${myPath}/serial_to_fermentrack_daemon" ]]; then
    rm "${myPath}/serial_to_fermentrack_daemon" >> "${UNINSTALL_LOG}" 2>&1 || printwarn "Failed to remove serial_to_fermentrack_daemon script"
  fi
  
  # Remove wheel from virtualenv using uv if it exists
  if [[ -d "${myPath}/.venv" ]]; then
    printinfo "Removing serial_to_fermentrack package from virtualenv..."
    # Only remove if it's installed and no other packages depend on it
    if command -v uv &> /dev/null; then
      # Activate the virtualenv
      source "${myPath}/.venv/bin/activate" >> "${UNINSTALL_LOG}" 2>&1
      # Check if package exists before trying to remove it
      if pip list | grep -q "serial-to-fermentrack"; then
        uv pip uninstall -y serial_to_fermentrack >> "${UNINSTALL_LOG}" 2>&1 || printwarn "Failed to uninstall serial_to_fermentrack package"
      fi
      deactivate >> "${UNINSTALL_LOG}" 2>&1 || true
    else
      printwarn "uv not found, skipping package removal"
    fi
  fi
  
  printinfo "Serial to Fermentrack uninstalled successfully"
  return 0
}

# BrewFlasher Command Line Edition uninstallation
uninstall_brewflasher() {
  printinfo "Uninstalling BrewFlasher Command Line Edition..."
  
  # Remove wrapper script
  if [[ -f "${myPath}/brewflasher" ]]; then
    rm "${myPath}/brewflasher" >> "${UNINSTALL_LOG}" 2>&1 || printwarn "Failed to remove brewflasher script"
  fi
  
  # Remove package from virtualenv using uv if it exists
  if [[ -d "${myPath}/.venv" ]]; then
    printinfo "Removing brewflasher_cli package from virtualenv..."
    # Only remove if it's installed and no other packages depend on it
    if command -v uv &> /dev/null; then
      # Activate the virtualenv
      source "${myPath}/.venv/bin/activate" >> "${UNINSTALL_LOG}" 2>&1
      # Check if package exists before trying to remove it
      if pip list | grep -q "brewflasher-cli"; then
        uv pip uninstall -y brewflasher_cli >> "${UNINSTALL_LOG}" 2>&1 || printwarn "Failed to uninstall brewflasher_cli package"
      fi
      deactivate >> "${UNINSTALL_LOG}" 2>&1 || true
    else
      printwarn "uv not found, skipping package removal"
    fi
  fi
  
  # Note: we don't uninstall avrdude as it might be used by other applications
  printinfo "BrewFlasher Command Line Edition uninstalled successfully"
  return 0
}

# TiltBridge Junior uninstallation
uninstall_tiltbridge_junior() {
  printinfo "Uninstalling TiltBridge Junior..."
  
  # Remove the TiltBridge Junior directory
  if [[ -d "${HOME}/fermentrack_tools/tiltbridge_junior" ]]; then
    rm -rf "${HOME}/fermentrack_tools/tiltbridge_junior" >> "${UNINSTALL_LOG}" 2>&1 || printwarn "Failed to remove TiltBridge Junior directory"
  fi
  
  # Check if fermentrack_tools is now empty, and remove if it is
  if [[ -d "${HOME}/fermentrack_tools" ]]; then
    if [[ -z "$(ls -A "${HOME}/fermentrack_tools")" ]]; then
      rmdir "${HOME}/fermentrack_tools" >> "${UNINSTALL_LOG}" 2>&1 || printwarn "Failed to remove empty fermentrack_tools directory"
    fi
  fi
  
  # Note: we don't uninstall Docker as it might be used by other applications
  printinfo "TiltBridge Junior uninstalled successfully"
  return 0
}

# Clean up shared virtual environment if empty
cleanup_virtualenv() {
  # Only attempt cleanup if no tools remain installed
  if [[ ${UNINSTALL_SERIAL} -eq 1 && ${UNINSTALL_BREWFLASHER} -eq 1 ]]; then
    if [[ -d "${myPath}/.venv" ]]; then
      printinfo "Checking if virtual environment can be removed..."
      
      # Check if any other packages are installed in the virtualenv
      # First, we need to activate the virtualenv
      source "${myPath}/.venv/bin/activate" >> "${UNINSTALL_LOG}" 2>&1
      
      # Get list of installed packages (excluding standard packages)
      local packages
      packages=$(pip list --format=columns | grep -v "^Package" | grep -v "^-" | grep -v "^pip" | grep -v "^setuptools" | grep -v "^wheel" | wc -l)
      deactivate >> "${UNINSTALL_LOG}" 2>&1 || true
      
      if [[ ${packages} -eq 0 ]]; then
        printinfo "Virtual environment is empty, removing..."
        rm -rf "${myPath}/.venv" >> "${UNINSTALL_LOG}" 2>&1 || printwarn "Failed to remove virtual environment"
      else
        printinfo "Virtual environment still contains other packages, keeping it"
      fi
    fi
  fi
}

# Keep track of uninstallation results
SERIAL_UNINSTALLED=false
BREWFLASHER_UNINSTALLED=false
TILTBRIDGE_UNINSTALLED=false

# Uninstallation summary
uninstallation_summary() {
  echo
  printinfo "Uninstallation summary:"
  echo
  if [[ ${UNINSTALL_SERIAL} -eq 1 ]]; then
    if [[ ${SERIAL_UNINSTALLED} == true ]]; then
      echo " - Serial to Fermentrack: Uninstalled"
    else
      echo " - Serial to Fermentrack: Uninstallation FAILED"
    fi
  fi

  if [[ ${UNINSTALL_BREWFLASHER} -eq 1 ]]; then
    if [[ ${BREWFLASHER_UNINSTALLED} == true ]]; then
      echo " - BrewFlasher Command Line Edition: Uninstalled"
    else
      echo " - BrewFlasher Command Line Edition: Uninstallation FAILED"
    fi
  fi

  if [[ ${UNINSTALL_TILTBRIDGE} -eq 1 ]]; then
    if [[ ${TILTBRIDGE_UNINSTALLED} == true ]]; then
      echo " - TiltBridge Junior: Uninstalled"
    else
      echo " - TiltBridge Junior: Uninstallation FAILED"
    fi
  fi

  echo
  printinfo "Uninstallation Complete."
}

# Main execution flow
main() {
  printinfo "Starting ${PACKAGE_NAME}..."
  get_user_selections
  
  if [[ ${UNINSTALL_SERIAL} -eq 1 ]]; then
    if uninstall_serial_to_fermentrack; then
      SERIAL_UNINSTALLED=true
    else
      printwarn "Serial to Fermentrack uninstallation failed."
    fi
  fi

  if [[ ${UNINSTALL_BREWFLASHER} -eq 1 ]]; then
    if uninstall_brewflasher; then
      BREWFLASHER_UNINSTALLED=true
    else
      printwarn "BrewFlasher uninstallation failed."
    fi
  fi

  if [[ ${UNINSTALL_TILTBRIDGE} -eq 1 ]]; then
    if uninstall_tiltbridge_junior; then
      TILTBRIDGE_UNINSTALLED=true
    else
      printwarn "TiltBridge Junior uninstallation failed."
    fi
  fi
  
  # Clean up shared resources
  cleanup_virtualenv
  
  # Remove logs directory if empty
  if [[ -d "${myPath}/logs" ]]; then
    if [[ -z "$(ls -A "${myPath}/logs")" ]]; then
      rmdir "${myPath}/logs" >> "${UNINSTALL_LOG}" 2>&1 || printwarn "Failed to remove empty logs directory"
    fi
  fi

  uninstallation_summary
}

# Start the uninstallation process
main