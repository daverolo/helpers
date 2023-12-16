#!/bin/bash
# -----------------------------------------------------------------------------
# What: Enable and/or renew Snakeoil SSL cert for Apache 2 at Hetzner LAMP stack for another 10 years
# Link: wget https://raw.githubusercontent.com/daverolo/helpers/main/global/renew_ssl.sh
# Usage : bash renew_ssl.sh
# -----------------------------------------------------------------------------

#
# HEADER
#

# Make sure piped errors will result in $? (https://unix.stackexchange.com/a/73180/452265)
set -o pipefail
	
# Set path manually since the script is maybe called via cron!
PATH=~/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

#
# CONFIG
#

# Init main vars
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPTDIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
SCRIPTNAME=$(basename "$SOURCE")
SCRIPTPATH="$SCRIPTDIR/$SCRIPTNAME"
SCRIPTUSER=$(whoami)
SCRIPTALIAS="${SCRIPTNAME%.*}"
USER=$(whoami)
HOST=$(hostname -s)
CURRENTDIR="$PWD"
HOST_NAME="$(hostname)"                                             # e.g. -> server1
OS_NAME="$(cat /etc/issue 2>/dev/null | awk -F " " '{print $1}')"   # e.g. -> Ubuntu

# Set the paths for the SSL certificate and key
CERT_PATH="/etc/ssl/certs/ssl-cert-snakeoil.pem"
KEY_PATH="/etc/ssl/private/ssl-cert-snakeoil.key"

# Set the validity period for the certificate in days (10 years)
VALIDITY_PERIOD=$((10 * 365))

# Public server address (to detected on Hetzner, may needs changes like "/24" instead of "/32" on hosts of other providers!)
SERVERADDR="$(ip a | grep /32 | awk '{print $2}' | head -c -4)"

#
# FUNCTIONS
#

# output default message
say() {
    echo "$@"
}

# exit script with error message and error code
die() {
    echo "$@" >&2
    exit 3
}

# Function to check if a string is a valid IPv4 address
is_valid_ipv4() {
    local ip=$1
    local valid_ipv4_regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
    if [[ $ip =~ $valid_ipv4_regex ]]; then
        return 0  # Valid IPv4 address
    else
        return 1  # Not a valid IPv4 address
    fi
}

#
# FLOW
#

# Check if the detected server IP address is a valid IPv4 address
if ! is_valid_ipv4 "$SERVERADDR"; then
    die "ERROR: The detected servers public IP address is not a valid IPv4 address."
fi

# Navigate to the SSL certificates directory
cd /etc/ssl/private/ || die "ERROR: could not change to /etc/ssl/private directory"

# Generate a new Snakeoil private key
sudo openssl genrsa -out "$KEY_PATH" 2048 || (cd "${SCRIPTDIR}" ; die "ERROR: could not create key")

# Generate a new Snakeoil certificate signing request (CSR)
sudo openssl req -new -key "$KEY_PATH" -out /tmp/ssl-cert-snakeoil.csr || (cd "${SCRIPTDIR}" ; die "ERROR: could not create csr")

# Generate a self-signed certificate using the CSR with a validity of 10 years
sudo openssl x509 -req -days "$VALIDITY_PERIOD" -in /tmp/ssl-cert-snakeoil.csr -signkey "$KEY_PATH" -out "$CERT_PATH" || (cd "${SCRIPTDIR}" ; die "ERROR: could not create cert")

# Navigate back to script directory
cd "${SCRIPTDIR}"

# Clean up the temporary CSR file
sudo rm /tmp/ssl-cert-snakeoil.csr &>/dev/null || true

# Set new DocumentRoot in default-ssl.conf
sudo sed -i.bak "s|\(^[[:space:]]*DocumentRoot[[:space:]]*\).*\$|\1/var/www/${SERVERADDR}|" /etc/apache2/sites-available/default-ssl.conf

# Restart Apache to apply the changes
#sudo systemctl restart apache2
# Reload Apache to apply the changes
sudo a2enmod ssl || true
sudo a2ensite default-ssl.conf || true
sudo systemctl reload apache2 || die "ERROR: could not reload apache2"

# Print a message indicating successful renewal
say "SSL certificate renewed and is now valid for 10 years."