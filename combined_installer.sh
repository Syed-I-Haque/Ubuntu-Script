#!/bin/bash

# Function to handle errors
error_exit() {
    echo "Error: $1" >&2
    logger -p error "$1"
    exit 1
}

# Function to log messages
log() {
    echo "$(date) - $1" | tee -a "$LOG_FILE"
}

# Function to check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error_exit "This script must be run as root."
    fi
}

# Function to detect Ubuntu version
detect_ubuntu_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$VERSION_ID"
    else
        error_exit "Unable to detect Ubuntu version."
    fi
}

# Function to install prerequisites
install_prerequisites() {
    echo "Installing prerequisites..."
    export DEBIAN_FRONTEND=noninteractive

    # Install required packages if not already installed
    packages="curl apt-transport-https gnupg anacron"
    for pkg in $packages; do
        if ! dpkg -l | grep -qw "$pkg"; then
            apt-get install -y "$pkg" || error_exit "Failed to install $pkg."
        else
            echo "$pkg is already installed."
        fi
    done
}

# Function to configure Microsoft repository
configure_ms_repo() {
    local ubuntu_version=$1
    echo "Configuring Microsoft repository for Ubuntu $ubuntu_version..."

    # Download and install the Microsoft repository package
    curl -sSL -o /tmp/microsoft-prod.deb https://packages.microsoft.com/config/ubuntu/${ubuntu_version}/packages-microsoft-prod.deb ||
        error_exit "Failed to download Microsoft repository package."

    dpkg -i /tmp/microsoft-prod.deb ||
        echo "Microsoft repository package already installed."

    rm /tmp/microsoft-prod.deb

    # Update the Microsoft repository
    apt-get update -o Dir::Etc::sourcelist="sources.list.d/microsoft-prod.list" \
        -o Dir::Etc::sourceparts="-" \
        -o APT::Get::List-Cleanup="0" ||
        error_exit "Failed to update Microsoft repository."
}

# Function to fix broken packages
fix_broken_packages() {
    echo "Fixing broken packages..."
    apt-get install -f || error_exit "Failed to fix broken packages."
}

# Function to install Defender for Endpoint
install_defender() {
    echo "Installing Microsoft Defender for Endpoint..."
    apt-get install -y mdatp >/dev/null || error_exit "Failed to install Microsoft Defender for Endpoint."
}

# Function to onboard the machine
onboard_machine() {
    local destfile="/etc/opt/microsoft/mdatp/mdatp_onboard.json"
    local destdir="/etc/opt/microsoft/mdatp"
    echo "Onboarding machine..."

    mkdir -p "$destdir" || error_exit "Failed to create directory $destdir."

    # Write the JSON content with cert
    cat >"$destfile" <<'EOF'
{
  "onboardingInfo": "{\"body\":\"{\\\"previousOrgIds\\\":[],\\\"orgId\\\":\\\"fd71d1fb-8c5d-45c1-b7a2-8665608fc0a5\\\",\\\"geoLocationUrl\\\":\\\"https://edr-ukw.uk.endpoint.security.microsoft.com/edr/\\\",\\\"datacenter\\\":\\\"WestUk\\\",\\\"vortexGeoLocation\\\":\\\"UK\\\",\\\"vortexServerUrl\\\":\\\"https://uk-v20.events.endpoint.security.microsoft.com/OneCollector/1.0\\\",\\\"vortexTicketUrl\\\":\\\"https://events.data.microsoft.com\\\",\\\"partnerGeoLocation\\\":\\\"GW_UK\\\",\\\"version\\\":\\\"1.7\\\",\\\"deviceType\\\":\\\"Server\\\"}\",\"sig\":\"k5MbX5DSleBhjrNHqu/CBqyj/HGUST6YW34gUF0/mGOqSPj4nXdEutXs7ObFuVFPuuwGyGvtJCEw8mOtI/s86TID5hQObDzXkypzOfgoaH9lMvYET7tB/U9/sLDdC2Z+m9Rrw9hLvapstehqwMJhxrRvblnOf3DiLuD3wzUhrXNYlznK0Ut7FxCV0j74/ansHTKWvg3a1UCusQoPv5RDcMAXpl67dCYkibv750nzaaD9B/tlx9VrKD3Mbsry+nIV3uXDdDr6IR8o6y0AMOWPUfLPsUcuF8aCndryehWXxIe6IL3K4qPcBSpMKq1WCarvBnbMn+OY6KEMQtWf+aCFmA==\",\"sha256sig\":\"k5MbX5DSleBhjrNHqu/CBqyj/HGUST6YW34gUF0/mGOqSPj4nXdEutXs7ObFuVFPuuwGyGvtJCEw8mOtI/s86TID5hQObDzXkypzOfgoaH9lMvYET7tB/U9/sLDdC2Z+m9Rrw9hLvapstehqwMJhxrRvblnOf3DiLuD3wzUhrXNYlznK0Ut7FxCV0j74/ansHTKWvg3a1UCusQoPv5RDcMAXpl67dCYkibv750nzaaD9B/tlx9VrKD3Mbsry+nIV3uXDdDr6IR8o6y0AMOWPUfLPsUcuF8aCndryehWXxIe6IL3K4qPcBSpMKq1WCarvBnbMn+OY6KEMQtWf+aCFmA==\",\"cert\":\"MIIFgzCCA2ugAwIBAgITMwAAAwiuH9Ak1Zb1UAAAAAADCDANBgkqhkiG9w0BAQsFADB+MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQgU2VjdXJlIFNlcnZlciBDQSAyMDExMB4XDTI0MDgyMjIwMDYwOVoXDTI1MDgyMjIwMDYwOVowHjEcMBoGA1UEAxMTU2V2aWxsZS5XaW5kb3dzLmNvbTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAK5GSnNoBWBUybDN/NOY+j+X4jpWFU84ZKKhoLD3JX1vcDBKId/o0xOoKVMIqcDGmdsX6Fjit2XssI9wHXvKiJdk/v9SQhJYhG3tFoip9+RmK+DPn3lMKDJx6KHhd/AIlMmp+4Ma433+BmDgMAIvbZDm1xRH4t9SwKlvBBwoQEs4zR0Nbz/aEkL7rD1CHIjIt++hGUQ4VRLnS4RUVXwIuFzvKiBnAR3WSbW0vVr5nU6al/WSinxJ+sLglC1aWWLO3EAGHrN4Ohnm5JK7lqEmbNyv7W6KOyFqnKfiDrk/DsUD0SJycoPNleRnJRTfbb6Rfmpbyr+bOt8yL27YF+crC/0CAwEAAaOCAVgwggFUMA4GA1UdDwEB/wQEAwIFIDAdBgNVHSUEFjAUBggrBgEFBQcDAQYIKwYBBQUHAwIwDAYDVR0TAQH/BAIwADAeBgNVHREEFzAVghNTZXZpbGxlLldpbmRvd3MuY29tMB0GA1UdDgQWBBQC/j4kVANjV6pF/RIxeCyCfnEKnDAfBgNVHSMEGDAWgBQ2VollSctbmy88rEIWUE2RuTPXkTBTBgNVHR8ETDBKMEigRqBEhkJodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNTZWNTZXJDQTIwMTFfMjAxMS0xMC0xOC5jcmwwYAYIKwYBBQUHAQEEVDBSMFAGCCsGAQUFBzAChkRodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY1NlY1NlckNBMjAxMV8yMDExLTEwLTE4LmNydDANBgkqhkiG9w0BAQsFAAOCAgEAQy6ejw037hwXvDPZF1WzHp/K0XxSHqr2WpixK3X3DHLuvcWaZJR8PhrsQGnjt+4epxrPaGdYgbj7TRLkFeKtUKiQIVfG7wbAXahHcknqhRkrI0LvWTfmLZtc4I2YXdEuKOnRoRIcbOT9NKBvc7N1jqweFPX7/6K4iztP9fyPhrwIHl544uOSRcrTahpO80Bmpz8n/WEVNQDc+ie+LI78adJh+eoiGzCgXSNhc8QbTKMZXIhzRIIf1fRKkAQxbdsjb/6kQ1hQ0u5RCd/eFCWODuCfpOAevJkn0rHmEzutbbFps/QdWwLyIj1HE+qTv5dNpYUx0oEGYtc83EIbGFZZyfrB6iDQvainmVp82La+Ahtw4+guVBLTSE7HKudob78WHX4WKBzJBKWUBlHM/lm67Qus28oU144qFMtsOg/rfN3J1J1ydT0GfulGJ8MR0+qJ9pk6ojv0W+F4mwuqkMWQuNAH9BL+5NkghtwBL0BwHpNyFtXzXiNf6s+cYuKGQsS4/ku4eczk/NRWryfXGjGM23zrpIsLkr5DCer34gjdTwn2TmQbWt+65pYyCpFc53v3ejCyTLz13O6JOFuXkL4K9QRqak9xtiGZik6EgTzKE4Ve6SIRFluxleV4UQ3XdzLb+903YD2Ke57PCpBHq/x35xcn+DzHVU3S2C/i43wUeKo=\",\"chain\":[\"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\"]}"
}
EOF

    if [ $? -eq 0 ]; then
        echo "Onboarding file created at $destfile."
        logger -p warning "Microsoft ATP: succeeded to save json file $destfile."
    else
        error_exit "Failed to create onboarding file at $destfile."
    fi
}

# Function to configure process exclusions
configure_exclusions() {
    echo "Configuring process exclusions..."

    # List of processes to exclude
    exclusions="/opt/google/chrome/chrome
/usr/sbin/NetworkManager
/usr/lib/snapd/snapd
/usr/libexec/tracker-miner-fs-3
/opt/zoom/zoom
/snap/firefox/5187/usr/lib/firefox/firefox
/opt/zoom/ZoomWebviewHost"

    # Apply global exclusions for each process
    echo "$exclusions" | while read -r process; do
        [ -z "$process" ] && continue
        echo "Adding global exclusion for $process"
        mdatp exclusion process add --path "$process" --scope global
    done

    # Verify the exclusions
    echo "Verifying exclusions:"
    mdatp exclusion list
}

# Function to set up scheduling
setup_scheduling() {
    echo "Setting up MDATP scheduling..."

    # Create script for MDATP update
    cat <<'EOF' >/etc/cron.weekly/mdatp_update
#!/bin/bash
LOG="/var/log/mdatp_update.log"
echo "$(date) - MDATP update started" >> "$LOG"
sleep $((RANDOM % 3600))
apt-get update && apt-get install --only-upgrade mdatp -y >> "$LOG" 2>&1
if [ $? -eq 0 ]; then
    echo "$(date) - MDATP update completed successfully." >> "$LOG"
else
    echo "$(date) - MDATP update failed." >> "$LOG"
fi
EOF

    # Create script for quick scan
    cat <<'EOF' >/etc/cron.daily/mdatp_quick_scan
#!/bin/bash
LOG="/var/log/mdatp_quick_scan.log"
echo "$(date) - Quick scan started" >> "$LOG"
sleep $((RANDOM % 3600))
/usr/bin/mdatp scan quick >> "$LOG" 2>&1
if [ $? -eq 0 ]; then
    echo "$(date) - Quick scan completed successfully." >> "$LOG"
else
    echo "$(date) - Quick scan failed." >> "$LOG"
fi
EOF

    # Set executable permissions
    chmod +x /etc/cron.weekly/mdatp_update /etc/cron.daily/mdatp_quick_scan || error_exit "Failed to set executable permissions for scripts."

    # Verify the creation of Anacron jobs
    if [ -x /etc/cron.weekly/mdatp_update ] && [ -x /etc/cron.daily/mdatp_quick_scan ]; then
        echo "Anacron jobs for MDATP update and quick scan have been set up successfully."
    else
        error_exit "Anacron jobs verification failed."
    fi

    echo "MDATP scheduling setup completed successfully."
}

# Main script execution
main() {
    check_root
    local ubuntu_version=$(detect_ubuntu_version)

    echo "Detected Ubuntu version: $ubuntu_version"

    install_prerequisites
    configure_ms_repo "$ubuntu_version"
    fix_broken_packages
    install_defender
    onboard_machine
    configure_exclusions
    setup_scheduling
}

# Run the main function
main
