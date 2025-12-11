#!/bin/bash

# Exit on error
set -e

# Define the kernel parameter to add
PARAM="i915.enable_guc=0"

# Path to the GRUB configuration file
GRUB_FILE="/etc/default/grub"

# Detect the actual system model
DETECTED_MODEL=$(sudo dmidecode -t system | grep "Product Name" | cut -d ":" -f2 | xargs)

echo "=========================================="
echo "Intel Graphics Kernel Parameter Setup"
echo "=========================================="
echo "Detected Model: $DETECTED_MODEL"
echo ""
echo "This script adds the kernel parameter: $PARAM"
echo ""
echo "This parameter is REQUIRED for:"
echo "  - Dell Precision 5690 (fixes Intel graphics issues)"
echo ""
echo "This parameter is OPTIONAL/NOT NEEDED for:"
echo "  - Dell Pro Max"
echo "  - Most other Dell models"
echo ""

# Prompt the user based on detected model
if [[ "$DETECTED_MODEL" == *"5690"* ]]; then
    echo "⚠️  Your model (Precision 5690) REQUIRES this parameter."
    read -p "Apply the kernel parameter? (yes/no): " user_input
else
    echo "ℹ️  Your model likely does NOT need this parameter."
    read -p "Do you want to apply it anyway? (yes/no): " user_input
fi

# Handle user choice - exit with success code if they say no
if [[ "$user_input" != "yes" ]]; then
    echo ""
    echo "Skipping kernel parameter addition."
    echo "Setup will continue..."
    exit 0  # Exit successfully (not an error)
fi

# Backup the current GRUB configuration
echo ""
echo "Backing up GRUB configuration..."
BACKUP_FILE="${GRUB_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
cp "$GRUB_FILE" "$BACKUP_FILE"
echo "Backup created: $BACKUP_FILE"

# Check if the parameter already exists in the file
if grep -q "$PARAM" "$GRUB_FILE"; then
    echo ""
    echo "✓ The parameter '$PARAM' is already present in $GRUB_FILE."
    echo "No changes needed."
else
    echo ""
    echo "Adding parameter to GRUB configuration..."
    
    # Add the parameter to the GRUB_CMDLINE_LINUX_DEFAULT line
    sed -i "/^GRUB_CMDLINE_LINUX_DEFAULT=/s/\"$/ $PARAM\"/" "$GRUB_FILE"
    
    echo "✓ The parameter '$PARAM' has been added to $GRUB_FILE."
    
    # Update GRUB to apply changes
    echo ""
    echo "Updating GRUB..."
    sudo update-grub
    
    echo ""
    echo "=========================================="
    echo "✓ GRUB configuration updated successfully"
    echo "=========================================="
    echo ""
    echo "IMPORTANT: Reboot required to apply changes."
fi

exit 0
