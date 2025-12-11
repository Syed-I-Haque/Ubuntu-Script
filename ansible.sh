#!/bin/bash

# Exit on error
set -e

#Configure all the ansible roles using Bash

#Removing Ubuntu bloatware, enable ufw and install 3rd party graphics drivers.
for i in \
          rhythmbox \
          transmission-common \
          transmission-gtk \
          totem \
          totem-plugins \
          totem-common \
          gnome-sudoku;do

sudo apt-get remove -yqq "$i"
done

sudo ufw enable 

sudo ubuntu-drivers autoinstall

source ./variables_env

#Adding git configuration
git config --global user.name "$useradaccount"
git config --global user.email "$useremail"
git config --global push.default "simple"
git config --global pull.rebase "true"
git config --global rebase.autostash "true"
git config --global core.autocrlf "input"
git config --global tag.annotated "true"
git config --global alias.ci "commit"
git config --global alias.co "checkout"
git config --global alias.st "status"

#Install Zoom
curl -fsSLO https://zoom.us/client/latest/zoom_amd64.deb
sudo apt install ./zoom_amd64.deb -y

#Install Chrome
curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
  | sudo gpg --dearmour -o /usr/share/keyrings/google_linux_signing_key.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google_linux_signing_key.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
  | sudo tee /etc/apt/sources.list.d/google.list > /dev/null
sudo apt-get update
sudo apt-get install google-chrome-stable -y

#Installing docker and adding a config file
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
for i in \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin;do
sudo apt-get install -yqq "$i"
done

envsubst < mintel_conf > mintel.conf
sudo install -D -o root -g root mintel.conf -t /etc/systemd/system/docker.service.d/
sudo systemctl daemon-reload
sudo systemctl restart docker

#Installing userpath, pipx and adding .local/bin to the PATH variable
pip install --user --no-warn-script-location userpath pipx
python3 -m userpath prepend "$HOME/.local/bin"

#Docker compose
sudo apt-get install docker-compose-plugin -yqq

#OpenVPN and other configurations
sudo install -m 700 -o "$USERNAME" -g "$USERNAME" -d "$MINTEL_VPN_DIR"
vpn_profile=("Mintel_London" "Mintel_Chicago" 
             "Mintel_London_Datacentre" "Mintel_China_Domestic"
             "Mintel_China_International")
for profile in "${vpn_profile[@]}";do
  envsubst < "./vpn/$profile" > "$profile"_VPN
done
for profile in "${vpn_profile[@]}";do
  sudo install -D -m 600 -o root -g root "$profile"_VPN -t \
    /etc/NetworkManager/system-connections/
done
sudo install -D -m 755 -o root -g root 90-mintel-openvpn-docker-routes -t /etc/NetworkManager/dispatcher.d/

#Wifi
wifi_profile=("Mintel_London" "Mintel_Chicago" "Mintel_Guest" "Mintel_Shanghai")
for profile in "${wifi_profile[@]}";do
  envsubst < "./wifi/$profile" > "$profile"_wifi
done
for profile in "${wifi_profile[@]}";do
  sudo install -D -m 600 -o root -g root "$profile"_wifi -t /etc/NetworkManager/system-connections/
done
dconf write /org/gnome/nm-applet/eap/"$UUID_LONDON"/ignore-phase2-ca-cert "'false'"
dconf write /org/gnome/nm-applet/eap/"$UUID_LONDON"/ignore-ca-cert "'true'"
dconf write /org/gnome/nm-applet/eap/"$UUID_CHICAGO"/ignore-phase2-ca-cert "'false'"
dconf write /org/gnome/nm-applet/eap/"$UUID_CHICAGO"/ignore-ca-cert "'true'"
dconf write /org/gnome/nm-applet/eap/"$UUID_SHANGHAI"/ignore-phase2-ca-cert "'false'"
dconf write /org/gnome/nm-applet/eap/"$UUID_SHANGHAI"/ignore-ca-cert "'true'"


#Changing Windows password from Linux
sudo DEBIAN_FRONTEND=noninteractive apt-get install krb5-user -yqq
envsubst < krb5 > krb5.conf
envsubst < k5 > k5identity
sudo install -m 644 -o root -g root krb5.conf /etc/krb5.conf
sudo install -m 600 -o "$USERNAME" -g "$USERNAME" k5identity "$HOME"/.k5identity 
sudo install -D -m 755 -o root -g root winpasswd -t /usr/local/bin/

#Portal tools
$HOME/.local/bin/pipx install --force --python /usr/bin/python3 black tox pipenv bump2version pre-commit poetry isort

#ssh config file
sudo install -D -m 600 -o "$USERNAME" -g "$USERNAME" config -t ~/.ssh/ 

#Manage Engine
unzip ./DefaultRemoteOffice_UEMSLinuxAgent.zip
sudo chmod +x UEMS_LinuxAgent.bin
sudo ./UEMS_LinuxAgent.bin

#Defender
sudo bash ./combined_installer.sh

#Intune and Edge
sudo bash ./Intune.sh

########################################
# DNS Configuration - FIXED VERSION
########################################

echo "=========================================="
echo "Configuring DNS resolution..."
echo "=========================================="

# Detect Ubuntu version
UBUNTU_VERSION=$(lsb_release -rs)
echo "Detected Ubuntu version: $UBUNTU_VERSION"

# Get the model to check for Dell 14 Pro or similar issues
DETECTED_MODEL=$(sudo dmidecode -t system | grep "Product Name" | cut -d ":" -f2 | xargs)
echo "Detected Model: $DETECTED_MODEL"

# Function to configure DNS without systemd-resolved
configure_dns_without_resolved() {
    echo "Disabling systemd-resolved..."
    sudo systemctl disable systemd-resolved.service
    sudo systemctl stop systemd-resolved
    
    # Backup existing resolv.conf if it exists and is not a symlink
    if [ -f /etc/resolv.conf ] && [ ! -L /etc/resolv.conf ]; then
        sudo cp /etc/resolv.conf /etc/resolv.conf.backup."$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Remove the symlink if it exists
    if [ -L /etc/resolv.conf ]; then
        sudo rm /etc/resolv.conf
    fi
    
    # Create a proper resolv.conf managed by NetworkManager
    sudo tee /etc/resolv.conf > /dev/null << 'EOF'
# Generated by NetworkManager
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
EOF
    
    echo "Created static /etc/resolv.conf with fallback DNS servers"
}

# Function to keep systemd-resolved but configure it properly
configure_dns_with_resolved() {
    echo "Keeping systemd-resolved enabled and configuring properly..."
    
    # Create resolved.conf.d directory if it doesn't exist
    sudo mkdir -p /etc/systemd/resolved.conf.d/
    
    # Configure systemd-resolved to use specific DNS servers
    sudo tee /etc/systemd/resolved.conf.d/mintel.conf > /dev/null << 'EOF'
[Resolve]
DNS=8.8.8.8 8.8.4.4 1.1.1.1
FallbackDNS=1.0.0.1
DNSStubListener=yes
EOF
    
    # Ensure systemd-resolved is enabled and running
    sudo systemctl enable systemd-resolved.service
    sudo systemctl restart systemd-resolved
    
    # Ensure resolv.conf is properly linked
    if [ ! -L /etc/resolv.conf ]; then
        sudo rm -f /etc/resolv.conf
        sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    fi
    
    echo "systemd-resolved configured with DNS servers"
}

# Decision logic based on Ubuntu version and model
if [[ "$UBUNTU_VERSION" == "24.04" ]] || [[ "$DETECTED_MODEL" == *"14 Pro"* ]] || [[ "$DETECTED_MODEL" == *"Pro Max"* ]]; then
    echo ""
    echo "⚠️  Ubuntu 24.04 or newer Dell model detected"
    echo "   Keeping systemd-resolved enabled to prevent network issues"
    echo ""
    configure_dns_with_resolved
else
    echo ""
    echo "ℹ️  Ubuntu $UBUNTU_VERSION detected"
    echo "   You can choose to disable systemd-resolved or keep it enabled"
    echo ""
    read -p "Disable systemd-resolved? (yes/no - recommend 'no' for newer systems): " disable_resolved
    
    if [[ "$disable_resolved" == "yes" ]]; then
        configure_dns_without_resolved
    else
        configure_dns_with_resolved
    fi
fi

# Install NetworkManager config
echo "Installing NetworkManager configuration..."
sudo install -m 644 -o root -g root NetworkManager.conf /etc/NetworkManager/

# Restart NetworkManager
echo "Restarting NetworkManager..."
sudo systemctl restart NetworkManager

# Wait a moment for network to stabilize
sleep 3

# Test DNS resolution
echo ""
echo "Testing DNS resolution..."
if host google.com > /dev/null 2>&1; then
    echo "✓ DNS resolution working"
else
    echo "⚠️  WARNING: DNS resolution test failed"
    echo "   If network is broken after reboot, run these commands:"
    echo "   sudo systemctl enable systemd-resolved"
    echo "   sudo systemctl start systemd-resolved"
    echo "   sudo systemctl restart NetworkManager"
fi

echo "DNS configuration complete"
echo "=========================================="

#docker-dnsdock and dnsmasq configuration
sudo apt-get install dnsmasq -y
sudo systemctl stop dnsmasq
# sudo install -D -o root -g root docker-system-dnsmasq.service -t /etc/systemd/system/
# sudo systemctl daemon-reload
# sudo systemctl stop docker-system-dnsmasq
# sudo install -m 644 -o root -g root NetworkManager.conf /etc/NetworkManager/
# envsubst < 90.docker > 90-docker
# sudo install -D -o root -g root 90-docker -t /etc/NetworkManager/dnsmasq.d/

# envsubst < docker-dnsdock-service > docker-dnsdock.service
# sudo install -D -o root -g root docker-dnsdock.service -t /etc/systemd/system/
# sudo systemctl daemon-reload
# sudo systemctl stop docker-dnsdock
# sudo systemctl enable docker-dnsdock docker-system-dnsmasq
# sudo systemctl start docker-dnsdock docker-system-dnsmasq
# sudo ufw allow from "$DOCKER_BRIDGE_RANGE" proto udp to "$DOCKER_BRIDGE" port 53
# sudo ufw allow from "$DOCKER_BRIDGE_RANGE" proto udp to "$DOCKER_BRIDGE" port 1053
# envsubst < ./dns_dock/minteldnsdock > ./dns_dock/mintel.conf
# sudo install -D -o root -g root ./dns_dock/mintel.conf -t /etc/systemd/system/docker.service.d/
# sudo systemctl daemon-reload
# sudo systemctl restart docker

#Disable Hardware Acceleration for Precision 5690
source ./parameter.sh

#TODO: Configuring Printers
