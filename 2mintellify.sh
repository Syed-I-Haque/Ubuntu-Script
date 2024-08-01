#!/bin/bash

echo " ╔════════════════════════════════════════════════╗"
echo " ║ Mintel Ubuntu 22.04 LTS Setup Script: Part 2   ║"
echo " ║                                                ║"
echo " ║                                                ║"
echo " ║             PRESS ENTER TO CONTINUE            ║"
echo " ╚════════════════════════════════════════════════╝"
read -p ""

########################################
# Prepare (system info, prompts, etc.) #
########################################
    
    
    home=~
    hostname="$(hostname)"
    serial="$(sudo dmidecode -t system | grep "Serial Number" | cut -d ":" -f2 | tr -d " ")"
    timestamp="$(date +%Y.%m.%d-%H%M)"
    mkdir -p "$(pwd)/mintel/logs"
    logfile="$(pwd)/mintel/logs/$hostname $timestamp.txt"
    touch "$logfile"
    
    set -a


    #Prompts
    prompts () {
        read -r -p "Your LastPass account name: " lastpass
        lpass login "$lastpass"
        echo ""
        read -r -p "User's Email Address: " useremail
        read -r -p "User's AD Account Name: " useradaccount
        read -s -r -p "User's AD Account Password: " useradpass
        addomain () {
            echo ""
            echo "User's AD Domain:"
            echo "    1. CHICAGO.MINTEL.AD"
            echo "    2. LONDON.MINTEL.AD"
            echo "    3. SHANGHAI.MINTEL.AD"
            read -r -p "Make a selection (1,2,3): " addomain
            if [[ "$addomain" = 1 ]];then
                addomain="CHICAGO"
            elif [[ "$addomain" = 2 ]];then
                addomain="LONDON"
            elif [[ "$addomain" = 3 ]];then
                addomain="SHANGHAI"
            else
                echo ""
                echo "INVALID SELECTION: Please select 1, 2, or 3."
                addomain
            fi
        }
        addomain
    }
    prompts

##########################
# Install/enable systemd #
##########################
    
    sudo bootctl install --path=/boot/efi
    sudo sed -i "s@quiet splash@quiet splash init=/lib/systemd/systemd@g" /etc/default/grub
    bootdefault=$(sudo efibootmgr | grep "BootCurrent" | cut -d " " -f2)
    sudo efibootmgr -o "$bootdefault"

############################
# Create LUKS recovery key #
############################
   
    crypt=$(cat /etc/crypttab | cut -d "_" -f1)
    lukskey=$(pwgen -s 27 1)
    printf '%s\n' "$serial" "$lukskey" "$lukskey" | sudo cryptsetup luksAddKey --key-slot 1 "/dev/$crypt"
    printf "Password: $lukskey" | lpass add --sync=now --non-interactive "Shared-Global Support/Ubuntu LUKS Keys/$hostname $timestamp"

#####################
# Integrate Ansible #
#####################

source ./ansible.sh

################################################################
# TODO: Modify /usr/bin/enroll-luks-key with crypt device name #
################################################################

####################################
# Append Summary to end of logfile #
####################################

    lpasspull=$(lpass show --sync=now --all --color=never "Shared-Global Support/Ubuntu LUKS Keys/$hostname $timestamp")
    echo "Mintel Ubuntu Setup Summary" >> "$logfile"
    echo "Configured for \"$useradaccount@$addomain.MINTEL.COM\" by $lastpass on $timestamp" >> "$logfile"
    echo "" >> "$logfile"
    echo "System Info" >> "$logfile"
    echo "    Hostname: $hostname" >> "$logfile"
    echo "    Service Tag: $serial" >> "$logfile"
    echo "LUKS Info" >> "$logfile"
    echo "    Partition: /dev/$crypt" >> "$logfile"
    echo "    Recovery Key: $lukskey" >> "$logfile"    
    echo "LastPass Confirmation" >> "$logfile"
    awk '{print "    "$0}' <<< $lpasspull >> "$logfile"
    #TODO - Add Contents of Logfile to notes field in LastPass Entry


########################
# Close out and reboot #
########################
    
    echo ""
    echo "Log file location: \"$logfile\""
    echo "Ubuntu Post-setup Checklist:"
    echo "    - Confirm log file is present and complete"
    echo "    - Confirm the Mintel Toolkit is on the user's desktop"
    echo "    - Review terminal window for errors or failures"
    echo ""
    read -p "Press ENTER to reboot..."
    reboot
