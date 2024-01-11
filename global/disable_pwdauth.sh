#!/bin/bash
# -----------------------------------------------------------------------------
# What: Disable SSH password authentication on Ubuntu 22.04 for all users and only allow key-based authentication
# Link: wget https://raw.githubusercontent.com/daverolo/helpers/main/global/disable_pwdauth.sh
# Usage: bash disable_pwdauth.sh
# Arguments:
# - None
# Examples:
# bash disable_pwdauth.sh
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

# init main vars
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

#
# CHECKS
#

# Make sure user is root
if [ "$(whoami)" != "root" ]; then
    die "error: call this script with sudo or as root"
fi

# Check if this is executed on Ubuntu or Debian (to prevent running this on the local OS by accident)
OS_NAME=$(echo "${OS_NAME}" | tr '[:upper:]' '[:lower:]')
if [ "${OS_NAME}" != 'ubuntu' ] && [ "${OS_NAME}" != 'debian' ]; then
    die "error: this script is only allowed to run on Ubuntu or Debian"
fi

#
# FLOW
#

# Backup the sshd_config file
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.$(date +%Y%m%d%H%M%S).bak || die "error: could not backup sshd_config"

# Disable PasswordAuthentication in sshd_config
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config &>/dev/null
sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config &>/dev/null

# Check if the modification was successful
if ! grep -q "^[[:space:]]*PasswordAuthentication no" /etc/ssh/sshd_config; then
    die "error: could not disable PasswordAuthentication in sshd_config - please do it manually!"
fi

# Restart the SSH service
systemctl restart ssh &>/dev/null || die "error: could not restart ssh service - please do it manually!"