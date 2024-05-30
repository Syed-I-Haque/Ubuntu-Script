#!/bin/bash

#Configure all the ansible roles using Bash

#Removing Ubuntu bloatware, enable ufw and install 3rd party graphics drivers.
for i in " \
          rhythmbox \
          transmission-common \
          transmission-gtk \
          totem \
          totem-plugins \
          totem-common \
          gnome-sudoku";do

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
for i in " \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin";do
sudo apt-get install -yqq "$i"
done

envsubst < mintel_conf > mintel.conf
sudo install -D -o root -g root mintel.conf -t /etc/systemd/system/docker.service.d/
sudo systemctl daemon-reload
sudo systemctl restart docker

#Installing userpath, pipx and adding .local/bin to the PATH variable
pip install --user userpath pipx
python3 -m userpath prepend "$HOME/.local/bin"

#Docker compose
sudo apt-get install docker-compose-plugin

#OpenVPN and other configurations
sudo install -m 700 -o "$USERNAME" -g "$USERNAME" -d "$MINTEL_VPN_DIR"
vpn_profile=("Mintel_London" "Mintel_Chicago" 
             "Mintel_London_Datacentre" "Mintel_China_Domestic"
             "Mintel_China_International")
for profile in "${vpn_profile[@]}";do
  envsubst < "./vpn/$profile" > "$profile"_VPN
done
for profile in "${vpn_profile[@]}";do
  sudo install -D -m 600 -o root -g root "$profile"_VPN \
  -t /etc/NetworkManager/system-connections/
done
sudo install -m 755 -o root -g root 90-mintel-openvpn-docker-routes /etc/NetworkManager/dispatcher.d/

#Wifi
wifi_profile=("Mintel_London" "Mintel_Chicago" "Mintel_Guest")
for profile in "${wifi_profile[@]}";do
  envsubst < "./wifi/$profile" > "$profile"_wifi
done
for profile in "${wifi_profile[@]}";do
  sudo install -D -m 600 -o root -g root "$profile"_wifi \
  -t /etc/NetworkManager/system-connections
done
dconf write /org/gnome/nm-applet/eap/"$UUID_LONDON"/ignore-phase2-ca-cert "'false'"
dconf write /org/gnome/nm-applet/eap/"$UUID_LONDON"/ignore-ca-cert "'true'"
dconf write /org/gnome/nm-applet/eap/"$UUID_CHICAGO"/ignore-phase2-ca-cert "'false'"
dconf write /org/gnome/nm-applet/eap/"$UUID_CHICAGO"/ignore-ca-cert "'true'"


#Changing Windows password from Linux
sudo apt-get install krb5-user
envsubst < krb5 > krb5.conf
envsubst < k5identity > k5identity
sudo install -m 644 -o root -g root krb5.conf /etc/krb5.conf
sudo install -m 600 k5identity "$HOME"/.k5identity 

#Portal tools
$HOME/.local/bin/pipx install --force --python /usr/bin/python3 black tox pipenv bumpversion pre-commit

#ssh config file
sudo install -m 600 -u "$USERNAME" -g "$USERNAME" config ~/.ssh/ 

#Manage Engine
unzip ./DefaultRemoteOffice_LinuxAgent.zip -d ./MEDC
cd ./MEDC
sudo chmod +x UEMS_LinuxAgent.bin
sudo ./UEMS_LinuxAgent.bin

#Kaspersky
sudo chmod +x ./klnagent64_14.2.0-35148_amd64.sh
sudo ./klnagent64_14.2.0-35148_amd64.sh


#docker-dnsdock and dnsmasq configuration
sudo apt-get install dnsmasq -y
sudo systemctl stop dnsmasq
sudo systemctl disable systemd-resolved.service
sudo systemctl stop systemd-resolved
sudo install -D -o root -g root docker-system-dnsmasq.service \ 
  -t /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl stop docker-system-dnsmasq
sudo install -m 644 -o root -g root NetworkManager.conf /etc/NetworkManager/
envsubst < 90.docker > 90-docker
sudo install -D -o root -g root 90-docker \ 
  -t /etc/NetworkManager/dnsmasq.d/
sudo rm /etc/resolv.conf
sudo systemctl restart NetworkManager
envsubst < docker-dnsdock-service > docker-dnsdock.service
sudo install -D -o root -g root docker-dnsdock.service \ 
  -t /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl stop docker-dnsdock
sudo systemctl enable docker-dnsdock docker-system-dnsmasq
sudo systemctl start docker-dnsdock docker-system-dnsmasq
sudo ufw allow from "$DOCKER_BRIDGE_RANGE" proto udp to "$DOCKER_BRIDGE" port 53
sudo ufw allow from "$DOCKER_BRIDGE_RANGE" proto udp to "$DOCKER_BRIDGE" port 1053
envsubst < minteldnsdock > minteldnsdock.conf
sudo install -D -o root -g root minteldnsdock.conf -t /etc/systemd/system/docker.service.d/mintel.conf
sudo systemctl daemon-reload
sudo systemctl restart docker



#TODO: Configuring Printers