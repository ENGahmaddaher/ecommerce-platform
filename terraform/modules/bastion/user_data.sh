#!/bin/bash
set -e

apt-get update -y
apt-get upgrade -y

apt-get install -y htop iotop nload tmux git vim curl wget jq awscli

# Configure SSH
sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config
systemctl restart sshd

useradd -m -s /bin/bash -G sudo admin || true
echo "admin ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/admin

cat > /etc/motd << EOF
==========================================
Bastion Host - ${environment}
Authorized access only
==========================================
EOF

ufw allow 22
ufw allow 80
ufw allow 443
ufw --force enable
