# Ubuntu Commander v1.3 - Project Overview

This document tracks the features and configuration of Ubuntu Commander 1.3.

## Core Features
- **Ubuntu Noble 24.04 LTS**: Latest stable base.
- **Dual Desktop Support**: Choice between XFCE4 (Lightweight) and MATE (Classic).
- **Multiple Display Protocols**: Support for VNC and Termux:X11.

## X11 Support (Termux:X11)
Termux:X11 is the recommended display protocol for Ubuntu Commander 1.3 due to its superior performance compared to VNC.

### Benefits:
- **Hardware Acceleration Support**: Lower latency and better frame rates.
- **Seamless Integration**: Works directly with the Termux:X11 Android app.
- **Native Resolution**: Better handling of Android screen scaling.

### Usage:
1. Install the Termux:X11 companion app on Android.
2. In Termux, run: `termux-x11 :0 &`
3. Inside Ubuntu, run: `start-x11` (configured via `complete_install.sh`).

## Utility Scripts
- `start-xrdp`: Managed xRDP session starter.
- `diagnose-xrdp`: Diagnostic tool for remote desktop troubleshooting.
- `complete_install.sh`: Unified interactive installer for desktops and protocols.

## Organization
- `utils/`: Contains auxiliary scripts for the rootfs.
- `ubuntu-rootfs/`: The base build directory.
- `build_ubuntu.sh`: The main image builder script.
