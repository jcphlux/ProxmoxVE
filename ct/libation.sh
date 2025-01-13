#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Proxmox Community Script: Libation Audible Backup in LXC
# Author: JCPhlux
# License: MIT | https://github.com/jcphlux/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/jcphlux/ProxmoxVE

# App Default Values
APP="Libation"
TAGS="backup;audiobooks;audible"
var_cpu=2
var_ram=2048
var_disk=8
var_os="debian"
var_version="12"
var_unprivileged=1

# App Output & Base Settings
header_info "$APP"
base_settings

# Core
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  msg_info "Installing dependencies"
  pct exec ${CTID} -- bash -c "apt update && apt install -y python3 python3-pip git ffmpeg"
  msg_ok "Dependencies installed"

  msg_info "Cloning Libation repository"
  pct exec ${CTID} -- git clone https://github.com/rmcrackan/Libation.git /root/Libation
  msg_ok "Repository cloned"

  msg_info "Installing Python requirements"
  pct exec ${CTID} -- pip3 install -r /root/Libation/requirements.txt
  msg_ok "Python requirements installed"

  msg_info "Setting up systemd service"
  pct exec ${CTID} -- bash -c 'cat <<EOF > /etc/systemd/system/libation.service
[Unit]
Description=Libation Audible Backup Service
After=network.target

[Service]
User=root
WorkingDirectory=/root/Libation
ExecStart=/usr/bin/python3 /root/Libation/libation.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF'
  pct exec ${CTID} -- systemctl daemon-reload
  pct exec ${CTID} -- systemctl enable libation
  pct exec ${CTID} -- systemctl start libation
  msg_ok "Systemd service configured"

  msg_info "Setting up cron job for automatic updates"
  pct exec ${CTID} -- bash -c 'cat <<EOF > /etc/cron.daily/libation-update
#!/bin/bash
REPO_DIR="/root/Libation"
LATEST_HASH=\$(git -C "\$REPO_DIR" rev-parse HEAD)
REMOTE_HASH=\$(git -C "\$REPO_DIR" ls-remote origin -h refs/heads/master | cut -f1)
if [ "\$LATEST_HASH" != "\$REMOTE_HASH" ]; then
  echo "Update available. Pulling latest changes..."
  git -C "\$REPO_DIR" pull
  systemctl restart libation
  echo "Libation service restarted after update."
else
  echo "No update required."
fi
EOF'
  pct exec ${CTID} -- chmod +x /etc/cron.daily/libation-update
  msg_ok "Cron job for automatic updates set up"

  msg_info "Creating default book and config directories"
  mkdir -p /mnt/Libation/Books
  msg_ok "Directories created"

  msg_info "Adding custom mounts to the LXC container"
  pct set ${CTID} -mp0 /mnt/Libation/Books,mp=/root/Libation/Books
  msg_ok "Custom mounts added"
}

function config_instructions() {
  echo -e "\n${INFO}${YW} To edit your Libation configuration, use the following commands:${CL}"
  echo -e "${TAB}${GN}nano /root/Libation/libation.config.json${CL}"
  echo -e "\n${INFO}${YW} Your audiobooks should be placed in the following directory:${CL}"
  echo -e "${TAB}${GN}/mnt/Libation/Books${CL}"
}

start
build_container
update_script
config_instructions

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
