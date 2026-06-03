markdown_content = """# 🚀 Ubuntu Automated Provisioning & Network Drive Setup

This repository contains two essential configuration files for automating the deployment of Ubuntu workstations and seamlessly mapping corporate network drives. Together, they provide a zero-touch installation experience followed by an intuitive, GUI-driven network drive configuration.

## 📑 Table of Contents
1. [Overview](#overview)
2. [Component 1: Cloud-Init Autoinstall Configuration](#component-1-cloud-init-autoinstall-configuration)
3. [Component 2: Interactive Network Drive Setup Script](#component-2-interactive-network-drive-setup-script)
4. [Usage Instructions](#usage-instructions)
5. [Security & Best Practices](#security--best-practices)

---

## 📖 Overview

The provisioning workflow is split into two distinct phases:
1. **Automated OS Installation (`cloud-config`)**: A YAML file that feeds directly into the Ubuntu subiquity installer to automate disk partitioning, user creation, locale settings, and the installation of third-party applications (like Chrome, Opera, and RustDesk).
2. **Post-Install Network Configuration (Bash Script)**: A user-friendly, interactive Bash script utilizing `zenity` to prompt the user for their secure SMB credentials and permanently mount a network drive using modern Systemd automounts.

---

## 🛠️ Component 1: Cloud-Init Autoinstall Configuration

The `cloud-config` YAML file acts as a fully unattended answer file for Ubuntu installations, providing a ready-to-use desktop environment out of the box.

### Core System Configuration
* **Timezone & Locale**: Enforces `Asia/Tbilisi` as the default timezone and `en_US.UTF-8` for the system locale.
* **Keyboard Layouts**: Configures a dual layout (`us,ge`) with `Alt+Shift` designated as the toggle key.
* **Storage Layout**: Automatically wipes the primary drive and sets up standard LVM (Logical Volume Manager) partitioning.

### Identity & Access Management
* **Administrator Profile**: Creates the primary machine admin (`administrator`) with a pre-hashed password.
* **Standard User Profile**: Creates a desktop user (`user`) assigned to standard operational groups (`cdrom, dip, plugdev, users`), isolated from root privileges.
* **SSH Server**: Installs OpenSSH and enables password authentication for remote administration.

### Software Pre-Seeding
Installs a curated list of utilities directly from the standard APT repositories, including:
* Remote Management: `remmina`
* Network & Download: `curl`, `wget`, `apt-transport-https`
* Version Control: `git`, `git-lfs`
* Media: `vlc`
* Codecs & Drivers: Enables proprietary drivers and media codecs automatically.

### Post-Install Software (Late-Commands)
To ensure the workstation has essential third-party software immediately, the system uses `late-commands` running inside a target `chroot` environment:
* **Web Browsers**: Installs **Google Chrome** via `.deb` and **Opera** via its official signed APT repository (with interactive prompts bypassed).
* **Remote Support**: Installs **RustDesk** (v1.4.6) directly from GitHub releases.
* **Productivity**: Installs **LibreOffice** and `unrar` for archive extraction.
* **Git**: Initializes Git Large File Storage (LFS) globally on the machine.

---

## 🔗 Component 2: Interactive Network Drive Setup Script

Once the system is built, end-users must connect to an internal SMB file share (`//10.50.0.100/Files`). To avoid manually editing `/etc/fstab` or exposing plain text passwords, this script securely mounts the drive via a graphical prompt.

### Workflow & Architecture
1. **Dependency Check**: Verifies that `zenity` (for the GUI) is installed. If executed via PolicyKit, it safely downloads `cifs-utils` and `smbclient` in the background.
2. **Graphical Prompt**: Displays a secure Zenity form asking for the user's SMB Username, SMB Password, and confirms the local desktop username to map permissions properly.
3. **Credential Storage**: Saves the SMB credentials into a locked-down, root-only file at `/etc/samba/creds-share` (`chmod 600`), preventing access by unauthorized local users.
4. **Fstab Injection (Systemd Automount)**: Injects a highly optimized `cifs` string into `/etc/fstab`.
   * It leverages `x-systemd.automount`, which lazily mounts the drive only when accessed. This drastically speeds up boot times and prevents the system from hanging if the corporate network is unreachable.
5. **Verification**: Restarts the systemd daemon and probes the mount point with a 10-second timeout. It returns a success dialog if mounted, or a detailed error dialog with kernel (`dmesg`) logs if the connection fails.

---

## 🚀 Usage Instructions

### 1. Bootstrapping the OS Installation
1. Save the YAML content into a file named `user-data`.
2. Package it into a custom Ubuntu autoinstall ISO or provide it via a local HTTP server using the `ds=nocloud-net` kernel parameter.
3. Boot the target machine. The installation will proceed automatically with zero interaction required.

### 2. Mounting the Network Drive
1. Log into the freshly provisioned Ubuntu machine as the main desktop user.
2. Ensure the script is executable:
   ```bash
   chmod +x setup_network_drive.sh
