#!/bin/bash
# -----------------------------------------------------------------------------
# What: Install Docker quick and dirty
# Link: wget https://github.com/daverolo/helpers/blob/main/core/installdocker.sh
# Usage: bash installdocker.sh
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

# trim whitespaces
# example: myvar=$(trim "$myvar")
trim() {
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"   
    echo -n "$var"
}

# replace all shell/environment vars in input variable name
# https://stackoverflow.com/a/9636423
# example: myvar=$(replacevars "myvar")
# note: there is NO dollar ($) sign in "myvar"!
replacevars() {	
	local inputvar="$1"   					# input var
	local inputvarname="$inputvar"   		# name of input var
	local inputvarcont="${!inputvarname}" 	# content of input var	
	for i in _ {a..z} {A..Z}; do
		for shellvar in `eval echo "\\${!$i@}"`; do # shell var (loop for each)
			#echo ">>> $shellvar <<<"
			local shellvarname="$shellvar"   		# name of shell var
			local shellvarcont="${!shellvar}" 			# content of shell var
			if [ "$shellvarname" != "$inputvarname" ]; then	
				local search="{$shellvarname}"					# search for string "{$shellvarname}" (e.g. "{myvar}")
				local replace="$shellvarcont"					# and replace with $shellvarcont
				inputvarcont=${inputvarcont//$search/$replace}	# in $inputvarcont
			fi
		done
	done
	echo "$inputvarcont" # return edited content of input var name
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
if [ "${OS_NAME}" != 'ubuntu' ] || [ "${OS_NAME}" != 'debian' ]; then
    die "error: this script is only allowed to run on Ubuntu or Debian"
fi

#
# Fetch args
upgrade="no"
oldcompose="no"
for arg in "$@"; do
    arg=${arg,,} # tolower
    if [ "$arg" = "upgrade" ] || [ "$arg" = "--upgrade" ]; then
        upgrade="yes"
    elif [ "$arg" = "oldcompose" ] || [ "$arg" = "--oldcompose" ]; then
        oldcompose="yes"
    fi
done

#
# FLOW
#

# Change to users home directory
cd ~ || die "error: could not change to home directory"

# Update apt repo and upgrade OS
if [ "$upgrade" = "yes" ]; then
	DEBIAN_FRONTEND=noninteractive apt-get -y --assume-yes update || die "error: could not update apt repo"
	DEBIAN_FRONTEND=noninteractive apt-get -y --assume-yes upgrade || die "error: failed to upgrade OS"
fi

# Install docker (and curl)
# https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
DEBIAN_FRONTEND=noninteractive apt-get -y --assume-yes update || die "error: could not update apt repo"
DEBIAN_FRONTEND=noninteractive apt-get -y --assume-yes install ca-certificates curl gnupg lsb-release || die "error: could not install ca-certificates"
mkdir -m 0755 -p /etc/apt/keyrings || die "error: could not create keyrings directory"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg || die "error: could not create docker.gpg"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null || die "error: could not create docker.list"
#chmod a+r /etc/apt/keyrings/docker.gpg
DEBIAN_FRONTEND=noninteractive apt-get -y --assume-yes update || die "error: could not update apt repo"
DEBIAN_FRONTEND=noninteractive apt-get -y --assume-yes install docker-ce docker-ce-cli containerd.io docker-buildx-plugin || die "error: could not install docker"

# Install docker-compose standalone (deprecated - use "docker compose" instead)
# https://docs.docker.com/compose/install/other/
if [ "$oldcompose" = "yes" ]; then
	curl -sL https://github.com/docker/compose/releases/download/v2.16.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose || die "error: could not download and install docker-compose"
	chmod +x /usr/local/bin/docker-compose || die "error: could not chmod docker-compose"
	ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose || die "error: could create symlink to docker-compose"
fi

# Done
say "Docker successfully installed"
say "You may run docker tests via:"
say "docker --version"
say "docker compose version"
if [ "$oldcompose" != "yes" ]; then
	say "docker-compose version"
fi
say "sudo docker run hello-world"
say "-----"
say "OPERATION COMPLETE - A REBOOT IS RECOMMENDED!"