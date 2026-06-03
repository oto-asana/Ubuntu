#!/bin/bash

# Ensure Zenity is installed
if ! command -v zenity &> /dev/null; then
    echo "[!] CRITICAL: Zenity is not installed. Run: sudo apt install zenity"
    exit 1
fi

DEFAULT_USER=$USER

# 1. Collect user data via UI
FORM_DATA=$(zenity --forms --title="IT Network Drive Setup" \
    --text="Enter configuration details below.\nSpecial characters in passwords are fully supported." \
    --separator="|" \
    --add-entry="SMB Username" \
    --add-password="SMB Password" \
    --add-entry="Main Desktop User (Found: $DEFAULT_USER)")

if [ -z "$FORM_DATA" ]; then
    echo "[-] Configuration canceled by user."
    exit 0
fi

SMB_USER=$(echo "$FORM_DATA" | awk -F'|' '{print $1}')
SMB_PASS=$(echo "$FORM_DATA" | awk -F'|' '{print $2}')
MAIN_USER=$(echo "$FORM_DATA" | awk -F'|' '{print $3}')
MAIN_USER=${MAIN_USER:-$DEFAULT_USER}

if ! id "$MAIN_USER" &>/dev/null; then
    zenity --error --title="Invalid User" --text="The User '$MAIN_USER' does not exist on this machine."
    exit 1
fi

MAIN_UID=$(id -u "$MAIN_USER")
MAIN_GID=$(id -g "$MAIN_USER")

# --- Step 2: Install Required System Dependencies ---
cat << 'EOF' > /tmp/install_deps.sh
#!/bin/bash
apt-get update -y && apt-get install -y cifs-utils smbclient
EOF
chmod +x /tmp/install_deps.sh
pkexec bash /tmp/install_deps.sh
rm -f /tmp/install_deps.sh


printf "username=%s\npassword=%s\n" "$SMB_USER" "$SMB_PASS" > /tmp/creds-share


echo "//10.50.0.100/Files /mnt/share cifs credentials=/etc/samba/creds-share,vers=3.0,uid=$MAIN_UID,gid=$MAIN_GID,file_mode=0700,dir_mode=0700,noauto,x-systemd.automount,x-systemd.mount-timeout=15,_netdev 0 0" > /tmp/fstab_line



cat << 'EOF' > /tmp/run_setup.sh
#!/bin/bash


systemctl stop mnt-share.automount 2>/dev/null
systemctl stop mnt-share.mount 2>/dev/null
umount -l /mnt/share 2>/dev/null || true


rm -f /etc/cron.d/automount_share /etc/sudoers.d/automount_share /usr/local/bin/mount_share.sh


mkdir -p /etc/samba
mv /tmp/creds-share /etc/samba/creds-share
chmod 600 /etc/samba/creds-share && chown root:root /etc/samba/creds-share


mkdir -p /mnt/share
chown root:root /mnt/share


sed -i '\|//10.50.0.100/Files|d' /etc/fstab
cat /tmp/fstab_line >> /etc/fstab


systemctl daemon-reload
systemctl enable mnt-share.automount
systemctl start mnt-share.automount


echo "[*] Probing network drive stability..."
timeout 10 ls /mnt/share > /dev/null 2>&1


if mount | grep -q "on /mnt/share type cifs"; then
    echo "SUCCESS" > /tmp/setup_result
else
    echo "FAILED" > /tmp/setup_result
   
    dmesg | grep -i cifs | tail -n 4 > /tmp/setup_err_details
fi
EOF

chmod +x /tmp/run_setup.sh


if ! pkexec bash /tmp/run_setup.sh; then
    zenity --error --title="Pipeline Error" --text="The execution engine failed completely. Check system terminal logs."
    rm -f /tmp/run_setup.sh /tmp/creds-share /tmp/fstab_line
    exit 1
fi


SETUP_STATUS=$(cat /tmp/setup_result 2>/dev/null)

if [ "$SETUP_STATUS" = "SUCCESS" ]; then
    zenity --info --title="Setup Complete" \
        --text="Success! The network drive is active and working perpetually.\n\nâ€¢ Location: /mnt/share\nâ€¢ Managed by: Systemd Automount Engine\nâ€¢ Validation Status: Connection Verified."
else
    ERR_LOG=$(cat /tmp/setup_err_details 2>/dev/null)
    zenity --error --title="Mount Verification Failed" \
        --text="The script updated system layouts, but your machine cannot connect to the server.\n\nPotential Causes:\n1. Wrong username or password.\n2. Server IP 10.50.0.100 is unreachable.\n\nKernel Diagnosis Log:\n$ERR_LOG"
fi


rm -f /tmp/run_setup.sh /tmp/creds-share /tmp/fstab_line /tmp/setup_result /tmp/setup_err_details
exit 0
