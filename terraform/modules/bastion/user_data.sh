#!/bin/bash
set -e
apt-get update -y
apt-get upgrade -y
apt-get install -y htop iotop nload tmux git vim curl wget jq awscli
cat >> /etc/ssh/sshd_config << EOF
PermitRootLogin no
PasswordAuthentication no
MaxAuthTries 3
EOF
useradd -m -s /bin/bash -G sudo admin || true
echo "admin ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/admin
