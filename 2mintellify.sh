#!/bin/bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail
trap 'echo "ERROR: Script failed on line $LINENO. Exit code: $?" >&2' ERR

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
model="$(sudo dmidecode -t system | grep "Product Name" | cut -d ":" -f2 | xargs)"
timestamp="$(date +%Y.%m.%d-%H%M)"
logdir="$(pwd)/mintel/logs"
mkdir -p "$logdir"
logfile="$logdir/$hostname $timestamp.txt"
touch "$logfile"

# Log both to file and console
exec > >(tee -a "$logfile") 2>&1

echo "=========================================="
echo "System Information"
echo "=========================================="
echo "Hostname: $hostname"
echo "Model: $model"
echo "Serial: $serial"
echo "Timestamp: $timestamp"
echo "=========================================="
echo ""

# Prompts
prompts () {
    # LastPass Login
    read -r -p "Your LastPass account name: " lastpass
    echo "Logging into LastPass..."
    if ! lpass login "$lastpass"; then
        echo "ERROR: LastPass login failed" >&2
        exit 1
    fi
    
    # Verify LastPass is logged in
    if ! lpass status -q; then
        echo "ERROR: LastPass authentication failed" >&2
        exit 1
    fi
    echo "LastPass login successful"
    echo ""
    
    # User Information
    read -r -p "User's Email Address: " useremail
    read -r -p "User's AD Account Name: " useradaccount
    read -s -r -p "User's AD Account Password: " useradpass
    echo "" # New line after hidden password input
    
    # AD Domain Selection
    addomain () {
        echo ""
        echo "User's AD Domain:"
        echo "    1. CHICAGO.MINTEL.AD"
        echo "    2. LONDON.MINTEL.AD"
        echo "    3. SHANGHAI.MINTEL.AD"
        read -r -p "Make a selection (1,2,3): " addomain_choice
        
        case "$addomain_choice" in
            1) addomain="CHICAGO" ;;
            2) addomain="LONDON" ;;
            3) addomain="SHANGHAI" ;;
            *)
                echo ""
                echo "INVALID SELECTION: Please select 1, 2, or 3."
                addomain
                return
                ;;
        esac
    }
    addomain
    
    echo ""
    echo "Configuration Summary:"
    echo "    Email: $useremail"
    echo "    AD Account: $useradaccount@$addomain.MINTEL.AD"
    echo ""
    read -r -p "Is this correct? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Restarting prompts..."
        prompts
        return
    fi
}
prompts

# Export variables for use in ansible.sh and child scripts
export useremail
export useradaccount
export useradpass
export addomain

##########################
# Install/enable systemd #
##########################

echo "=========================================="
echo "Configuring systemd boot..."
echo "=========================================="

if ! sudo bootctl install --path=/boot/efi; then
    echo "WARNING: bootctl install failed, may already be installed"
fi

# Backup GRUB config before modifying
sudo cp /etc/default/grub /etc/default/grub.backup."$timestamp"

if ! grep -q "init=/lib/systemd/systemd" /etc/default/grub; then
    sudo sed -i "s@quiet splash@quiet splash init=/lib/systemd/systemd@g" /etc/default/grub
    sudo update-grub
    echo "GRUB updated with systemd init"
else
    echo "GRUB already configured for systemd"
fi

bootdefault=$(sudo efibootmgr | grep "BootCurrent" | cut -d " " -f2)
sudo efibootmgr -o "$bootdefault"
echo "Boot order set to: $bootdefault"
echo ""

############################
# Create LUKS recovery key #
############################

echo "=========================================="
echo "Configuring LUKS encryption..."
echo "=========================================="

# Check if crypttab exists and has entries
if [ ! -f /etc/crypttab ] || [ ! -s /etc/crypttab ]; then
    echo "ERROR: /etc/crypttab not found or empty. LUKS encryption may not be configured." >&2
    exit 1
fi

crypt=$(cut -d "_" -f1 /etc/crypttab | head -n1)
if [ -z "$crypt" ]; then
    echo "ERROR: Could not determine LUKS device from /etc/crypttab" >&2
    exit 1
fi

echo "LUKS device detected: /dev/$crypt"

# Verify the device exists
if [ ! -b "/dev/$crypt" ]; then
    echo "ERROR: LUKS partition /dev/$crypt not found" >&2
    exit 1
fi

# Generate recovery key
lukskey=$(pwgen -s 27 1)
echo "Generated LUKS recovery key"

# Add LUKS key to slot 1
echo "Adding recovery key to LUKS slot 1..."
if printf '%s\n' "$serial" "$lukskey" "$lukskey" | sudo cryptsetup luksAddKey --key-slot 1 "/dev/$crypt"; then
    echo "LUKS recovery key added successfully"
else
    echo "ERROR: Failed to add LUKS recovery key" >&2
    exit 1
fi

# Verify key was added
if sudo cryptsetup luksDump "/dev/$crypt" | grep -q "Slot 1:.*ENABLED"; then
    echo "Verified: LUKS key slot 1 is enabled"
else
    echo "WARNING: Could not verify LUKS key slot 1"
fi

# Store in LastPass
lastpass_path="Shared-Global Support/Ubuntu LUKS Keys/$hostname $timestamp"
echo "Storing recovery key in LastPass..."
if printf "Password: %s\nDevice: /dev/%s\nSerial: %s\nModel: %s" "$lukskey" "$crypt" "$serial" "$model" | \
   lpass add --sync=now --non-interactive "$lastpass_path"; then
    echo "Recovery key stored in LastPass: $lastpass_path"
else
    echo "ERROR: Failed to store key in LastPass" >&2
    echo "CRITICAL: Recovery key is: $lukskey (save this manually!)" >&2
    read -p "Press ENTER to continue anyway or CTRL-C to abort..."
fi
echo ""

#####################
# Integrate Ansible #
#####################

echo "=========================================="
echo "Running Ansible integration..."
echo "=========================================="

if [ ! -f "./ansible.sh" ]; then
    echo "ERROR: ansible.sh not found in current directory" >&2
    exit 1
fi

if source ./ansible.sh; then
    echo "Ansible integration completed"
else
    ansible_exit_code=$?
    echo "WARNING: Ansible integration script failed (exit code: $ansible_exit_code)"
    read -p "Continue anyway? (y/n): " continue_ansible
    if [[ ! "$continue_ansible" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
echo ""

################################################################
# TODO: Modify /usr/bin/enroll-luks-key with crypt device name #
################################################################

# Placeholder for future implementation
if [ -f /usr/bin/enroll-luks-key ]; then
    echo "Found /usr/bin/enroll-luks-key"
    echo "TODO: Modify with crypt device name: /dev/$crypt"
fi

####################################
# Append Summary to end of logfile #
####################################

echo "=========================================="
echo "Generating summary..."
echo "=========================================="

# Retrieve LastPass entry for verification
lpasspull=$(lpass show --sync=now --all --color=never "$lastpass_path" 2>/dev/null || echo "Failed to retrieve LastPass entry")

{
    echo ""
    echo "=========================================="
    echo "Mintel Ubuntu Setup Summary"
    echo "=========================================="
    echo "Configured for: $useradaccount@$addomain.MINTEL.AD"
    echo "Configured by: $lastpass"
    echo "Date: $timestamp"
    echo ""
    echo "System Info"
    echo "    Hostname: $hostname"
    echo "    Model: $model"
    echo "    Service Tag: $serial"
    echo ""
    echo "LUKS Info"
    echo "    Partition: /dev/$crypt"
    echo "    Recovery Key: $lukskey"
    echo ""
    echo "LastPass Confirmation"
    echo "$lpasspull" | sed 's/^/    /'
    echo ""
    echo "=========================================="
} | tee -a "$logfile"

########################
# Close out and reboot #
########################

echo ""
echo "╔════════════════════════════════════════════════╗"
echo "║           SETUP COMPLETE                        ║"
echo "╚════════════════════════════════════════════════╝"
echo ""
echo "Log file location: $logfile"
echo ""
echo "Ubuntu Post-setup Checklist:"
echo "    ✓ Review log file is present and complete"
echo "    ✓ Confirm the Mintel Toolkit is on the user's desktop"
echo "    ✓ Review terminal output above for any warnings/errors"
echo "    ✓ Verify LastPass entry was created"
echo ""
echo "IMPORTANT: Recovery key stored in LastPass at:"
echo "    $lastpass_path"
echo ""
read -p "Press ENTER to reboot or CTRL-C to exit without rebooting..."
sudo reboot
