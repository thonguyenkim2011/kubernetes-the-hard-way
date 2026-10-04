#!/usr/bin/env bash

MTU=${1:-1400}

# Set hostfile entries
sudo sed -i "/$(hostname)/d" /etc/hosts
cat /tmp/hostentries | sudo tee -a /etc/hosts &> /dev/null

# cloud-init rewrites /etc/hosts from this template on every boot, which would
# drop the entries above after a VM restart. Add them to the template as well.
HOSTS_TEMPLATE=/etc/cloud/templates/hosts.debian.tmpl
if [ -f $HOSTS_TEMPLATE ]; then
    sudo sed -i '/# kthw$/d' $HOSTS_TEMPLATE
    sed 's/$/ # kthw/' /tmp/hostentries | sudo tee -a $HOSTS_TEMPLATE > /dev/null
fi

# Lower the MTU. The path from Multipass VMs to the internet often cannot carry
# 1500 byte packets (VPNs, some home routers) and the ICMP messages that would
# reveal this are dropped, so large TLS packets vanish and image pulls time out.
IFACE=$(ip route | awk '/default/ { print $5; exit }')
sudo ip link set dev "$IFACE" mtu "$MTU"
# Persist it, reusing the interface id from the cloud-init netplan config so the settings merge
NETPLAN_ID=$(sudo awk '/^ *ethernets:/ { getline; sub(/^ */, ""); sub(/:.*/, ""); print; exit }' /etc/netplan/50-cloud-init.yaml 2>/dev/null)
cat <<EOF | sudo tee /etc/netplan/60-mtu.yaml > /dev/null
network:
  version: 2
  ethernets:
    ${NETPLAN_ID:-$IFACE}:
      mtu: $MTU
EOF
sudo chmod 600 /etc/netplan/60-mtu.yaml
sudo netplan generate || { echo "netplan rejected the MTU setting; MTU will reset on reboot"; sudo rm -f /etc/netplan/60-mtu.yaml; }

# Export internal IP of primary NIC as an environment variable
echo "PRIMARY_IP=$(ip route | grep default | awk '{ print $9 }')" | sudo tee -a /etc/environment > /dev/null

# Export architecture as environment variable to download correct versions of software
echo "ARCH=arm64"  | sudo tee -a /etc/environment > /dev/null

# Enable password auth in sshd so we can use ssh-copy-id
# Enable password auth in sshd so we can use ssh-copy-id
sudo sed -i --regexp-extended 's/#?PasswordAuthentication (yes|no)/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i --regexp-extended 's/#?Include \/etc\/ssh\/sshd_config.d\/\*.conf/#Include \/etc\/ssh\/sshd_config.d\/\*.conf/' /etc/ssh/sshd_config
sudo sed -i 's/KbdInteractiveAuthentication no/KbdInteractiveAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl restart sshd

if [ "$(hostname)" = "controlplane01" ]
then
    sh -c 'sudo apt update' &> /dev/null
    sh -c 'sudo apt-get install -y sshpass' &> /dev/null
 fi

# Set password for ubuntu user (it's something random by default)
echo 'ubuntu:ubuntu' | sudo chpasswd