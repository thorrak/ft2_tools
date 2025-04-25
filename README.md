# Fermentrack 2 Tools Installer

This repository contains installation scripts for deploying support tools that bridge locally-connected devices to Fermentrack 2.

## Overview

Fermentrack 2 is designed to run in the cloud, creating challenges for hardware devices that previously connected 
directly to a local Fermentrack installation (typically on a user's Raspberry Pi). This installer sets up tools 
that enable continued use of serial-connected BrewPi temperature controllers and Bluetooth-connected Tilt Hydrometers 
devices with cloud-based Fermentrack 2. 

This also sets up BrewFlasher CLI Edition, which allows using a Raspberry Pi to flash brewing-related firmware to 
ESP8266, ESP32, and Arduino devices - even if those devices will ultimately be used over WiFi.

## Included Tools

The installer supports installing these tools:

- **Serial-to-Fermentrack**: Connects serial BrewPis (ESP-based or Arduino-based) to Fermentrack 2
- **TiltBridge Junior**: Uses the device's Bluetooth radio to relay Tilt Hydrometer broadcasts to Fermentrack 2
- **BrewFlasher Command Line Edition**: Allows flashing brewing-related firmware to ESP8266, ESP32, and Arduino devices

## Installation

### Quick Install (Recommended)

Run this command to download and execute the installer automatically, over the internet:

```bash
bash <(curl -sSL https://localtools.fermentrack.net/)
```

### Manual Install

If you've already downloaded this repository:

1. Make the installer executable (if it isn't already): `chmod +x ft2_tools_installer.sh`
2. Run the installer: `./ft2_tools_installer.sh`

### Upgrading

To upgrade existing installations:

```bash
./upgrade.sh
```

This will automatically detect which tools are installed and upgrade them to the latest versions.


## Using the Tools

### Serial-to-Fermentrack

After installation:

1. Configure connections by running: `./serial_to_fermentrack_config`
2. If auto-start was enabled during installation, devices will automatically begin updating in Fermentrack. Otherwise, launch manually with: `./serial_to_fermentrack_daemon`

**Important**: Devices are configured based on their physical USB port connection. If you change the USB port, the device will no longer be detected or may be detected as a different device.


### BrewFlasher Command Line Edition

After installation:

1. Run the command: `./brewflasher`
2. Follow the on-screen prompts

**Warning**: Do not flash a device that is currently plugged into a USB port configured for Serial-to-Fermentrack. To upgrade firmware on a controller in use, connect it to a different USB port.


### TiltBridge Junior

Instructions to come at a later date, when Fermentrack 2 gravity support is available for use.

## Uninstallation

If you need to uninstall any of the tools:

1. Make the uninstaller executable (if it isn't already): `chmod +x uninstall.sh`
2. Run the uninstaller: `./uninstall.sh`
3. Follow the prompts to select which tools to uninstall

You can also run in non-interactive mode:
```bash
# Uninstall specific tools
./uninstall.sh -s -b    # Uninstall Serial-to-Fermentrack and BrewFlasher
./uninstall.sh -t       # Uninstall TiltBridge Junior
./uninstall.sh -n -s -b -t  # Uninstall all tools non-interactively
```


## Repository Structure

- `bootstrap.sh`: Script designed to be run directly from the internet to download this repository and run the installer
- `ft2_tools_installer.sh`: Main installation script that installs all local tools
- `uninstall.sh`: Script to uninstall tools previously installed by ft2_tools_installer.sh
- `upgrade.sh`: Script to upgrade previously installed tools to their latest versions

### Created Executables

- `serial_to_fermentrack_config`: Configuration script for the serial-to-Fermentrack bridge
- `serial_to_fermentrack`: The actual serial-to-Fermentrack bridge, run once per device by the daemon (Not typically run directly by a user)
- `serial_to_fermentrack_daemon`: Daemon that runs the serial-to-Fermentrack bridge (Not typically run directly by a user)
- `brewflasher`: BrewFlasher CLI Edition, used to flash ESP8266, ESP32, and Arduino devices

## Development and Testing

This repository includes a comprehensive test suite using [ShellSpec](https://shellspec.info/). See the `spec` directory for test files and documentation:

```bash
# Install ShellSpec
curl -fsSL https://git.io/shellspec | sh -s -- --yes

# Run all tests
shellspec

# Run specific test files
shellspec spec/installer_spec.sh
```
