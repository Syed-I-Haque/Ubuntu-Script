#!/bin/bash

LOGFILE="/var/log/setup_script.log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOGFILE"
}

# Exit on error with message
abort() {
    log "ERROR: $1"
    exit 1
}


log "Adding Microsoft Edge and Intune repository."
 echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/microsoft-prod.gpg] \
 https://packages.microsoft.com/repos/edge stable main" | tee /etc/apt/sources.list.d/microsoft-edge.list >> \
 "$LOGFILE" 2>&1 || abort "Failed to add the Microsoft repository."

log "Starting system update..."
apt-get update >>"$LOGFILE" 2>&1 || abort "apt update failed."
log "System update completed."

log "Installing Microsoft Edge."
apt-get install microsoft-edge-stable -y >>"$LOGFILE" 2>&1 || abort "Failed to install Edge."
log "Microsoft Edge installed successfully."

log "Installing Microsoft Intune App..."
apt-get install intune-portal -y >> "$LOGFILE" || abort "Failed to install Intune"
log "Microsoft Intune App installed successfully."

log "Installation finished successfully."
