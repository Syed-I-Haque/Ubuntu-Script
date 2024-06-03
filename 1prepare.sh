#!/bin/bash
touch .prepare.log
sudo apt-get update

###########################################################
# Install LastPass and Create hidden supportadmin account #
###########################################################
    #LastPass Prereqs/Make/Login
    echo "Installing LastPass, standby for login..."
    for i in \
        bash-completion \
        build-essential \
        cmake \
        git \
        libcurl4 \
        libcurl4-openssl-dev \
        libssl-dev \
        libxml2 \
        libxml2-dev \
        libssl3 \
        make \
        pkg-config \
        ca-certificates \
        xclip; do 
    sudo apt-get --no-install-recommends -yqq install $i
    done
    git clone https://github.com/LastPass/lastpass-cli ~/.lastpass
    sudo make -C ~/.lastpass install
    lpass --version
    [ $? -ne 0 ] && echo "LastPass Install Failed" && exit 1
    read -r -p "Enter Your LastPass account name: " lastpass
    lpass login "$lastpass"
    adminpass=$(lpass show --password 3637874273922668030)
    sudo useradd -rmUG adm,sudo supportadmin
    printf '%s\n' "$adminpass" "$adminpass" | sudo passwd supportadmin

###################
# Install Prereqs #
###################
sudo apt-get update

    #Common Packages: Tools\
    echo "Installing Common Tools..."
    for i in \
        build-essential \
        bzip2 \
        curl \
        gawk \
        git \
        git-lfs \
        git-svn \
        graphviz \
        htop \
        httpie \
        jq \
        make \
        p7zip-full \
        ranger \
        rclone \
        rsync \
        screen \
        subversion \
        tmux \
	gettext \
	uuid-runtime \
        vim \
        wget \
        xz-utils; do 
    sudo apt-get install -yqq $i
    done

    #Common Packages: PostgreSQL
    echo "Installing PostgreSQL Prereqs..."
    for i in \
        postgresql-client \
        libpq-dev; do 
    sudo apt-get install -yqq $i
    done
    
    #Common Packages: MySQL
    echo "Installing MySQL Prereqs..."
    for i in \
        mysql-client \
        libmysqlclient-dev; do 
    sudo apt-get install -yqq $i
    done

    #Common Packages: Python
    echo "Installing Python Prereqs..."
    for i in \
        python \
        python-pip \
        python-virtualenv \
        python3 \
        python3-pip \
	python3-venv \
        python3-virtualenv; do 
    sudo apt-get install -yqq $i
    done

    #Common Packages: Library Sources
    echo "Installing Library Sources..."
    for i in \
        libyaml-dev \
	libxmlsec1-dev \
	liblasso3-dev \
	libxslt1-dev; do 
    sudo apt-get install -yqq $i
    done

    #Common Packages: Other (do not include ubuntu-restricted-extras)
    echo "Installing Misc. Tools..."
    for i in \
        vlc \
        gimp \
        libreoffice \
        gnome-tweaks \
        pwgen \
        software-properties-common \
        tlp \
        unattended-upgrades \
        ufw \
        ubuntu-drivers-common \
        autorandr \
        sosreport; do 
    sudo apt-get install -yqq $i
    done

    #DisplayLink Prereqs
    echo "Installing DisplayLink Prereqs..."
    for i in \
        dkms \
        gawk \
        wget \
        unzip \
        lsb-release \
        linux-source \
        python-pexpect \
        perl; do 
    sudo apt-get install -yqq $i
    done

    #OpenVPN Prereqs
    echo "Installing OpenVPN Prereqs..."
    for i in \
        network-manager-openvpn \
        network-manager-openvpn-gnome \
        network-manager; do 
    sudo apt-get install -yqq $i
    done

    #Mintel Printing Prereqs
    echo "Installing Printing Prereqs..."
    for i in \
        openprinting-ppds \
        smbclient; do 
    sudo apt-get install -yqq $i
    done

    #Mintel Wifi Prereqs
    echo "Installing Wifi Prereqs..."
    for i in \
        network-manager \
        python-psutil; do 
    sudo apt-get install -yqq $i
    done
    
    #Yubikey-GPG Prereqs
    echo "Installing Yubikey-GPG Prereqs..."
    for i in \
        scdaemon \
        yubikey-personalization \
        ldapscripts; do 
    sudo apt-get install -yqq $i
    done

    #Active Directory Prereqs (do not include, KRB5 install not silent)
    #OCS Prereqs (do not include, OCS install not silent)

    #Ansible, Yubikey-LUKS
    for i in \
        ansible \
        yubikey-luks; do 
    sudo apt-get install -yqq $i
    done

#######################################
# Dist-Upgrade #
#######################################

    sudo apt-get update
    sudo apt-get dist-upgrade -y

#####################################
# TODO: Run success checks, reboot. #
#####################################

    echo ""
    echo " ╔════════════════════════════════════════════════╗"
    echo " ║ Mintel Ubuntu Setup Script Part 1: COMPLETE    ║"
    echo " ║    + Review terminal output for errors         ║"
    echo " ║    + This script can be re-run if needed       ║"
    echo " ║    + Press ENTER to reboot or CTRL-V to exit   ║"
    echo " ╚════════════════════════════════════════════════╝"
    read -p ""
    rm .prepare.log
    reboot
