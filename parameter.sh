#!/bin/bash

# Define the kernel parameter to add
PARAM="i915.enable_guc=0"

# Path to the GRUB configuration file
GRUB_FILE="/etc/default/grub"

# Backup the current GRUB configuration
cp "$GRUB_FILE" "${GRUB_FILE}.bak"

# Prompt the user if the system matches the specific Dell model
read -p "Are you building a Precision 5690 (yes/no)? " user_input

if [[ "$user_input" != "yes" ]]; then
    echo "User chose not to proceed. Exiting."
    exit 1
fi

# Check if the parameter already exists in the file
if grep -q "$PARAM" "$GRUB_FILE"; then
    echo "The parameter '$PARAM' is already present in $GRUB_FILE."
else
    # Add the parameter to the GRUB_CMDLINE_LINUX_DEFAULT line
    sed -i "/^GRUB_CMDLINE_LINUX_DEFAULT=/s/\"$/ $PARAM\"/" "$GRUB_FILE"
    
    echo "The parameter '$PARAM' has been added to $GRUB_FILE."
fi

# Update GRUB to apply changes
update-grub

echo "GRUB configuration updated. Reboot to apply the changes."
