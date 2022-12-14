#!/bin/bash

# ====================================================================================
# SYNCLINK API SPEC SETUP/UPDATE SCRIPT
# -------------------------------------
# This script will setup and automatically update all services to provide the SyncLink
# API Spec publicly via Apache HTTP Server by using mod_proxy.
# After the first download the script will also auto-update itself whenever executed.
# ====================================================================================
# DOWNLOAD
# --------
# cd ~ && wget -O update.sh https://raw.githubusercontent.com/daverolo/helpers/main/machine-synclink-api-spec/update.sh
# ====================================================================================
# EXECUTE 
# -------
# bash update.sh
# ====================================================================================

#
# ESSENTIALS
#

# sSetet path manually on top since the script is also called via cron!
PATH=~/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Move to home dir
cd ~

#
# INIT VARS
#

# Init basic vars
ScriptVer="1.0.8"
HttpFileStorage="https://raw.githubusercontent.com/daverolo/helpers/main/machine-synclink-api-spec"

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
UNIX_TIMESTAMP=$(date +%s)
CRONHASH=($(echo "$SCRIPTPATH" | md5sum)) # HASH OF THE SCRIPTS FILE PATH (NOT THE CONTENT!)
CRONFILE=/etc/cron.d/$(basename "$SCRIPTDIR")-"${SCRIPTALIAS}-${CRONHASH}" # MUST NOT HAVE FILE EXTENSION!

#
# FUNCTIONS
#

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

#
# CHECK PERMISSIONS
#

# Require root
if [ "$SCRIPTUSER" != "root" ]; then
    echo "This script requires root permission to run - abort!"
    exit 3
fi

#
# AUTO UPDATE
#

# Download source and auto update if hash is different (and file exists on remote host)
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
echo "Checking script for updates"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
wget --spider -q "$HttpFileStorage/$SCRIPTNAME?$UNIX_TIMESTAMP"; exitcode=$?
if [ $exitcode = 0 ]; then
	wget -q -O "$SCRIPTPATH.updatecheck" "$HttpFileStorage/$SCRIPTNAME?$UNIX_TIMESTAMP"	
	if [ $exitcode != 0 ] || ! [ -f "$SCRIPTPATH.updatecheck" ] ; then
		echo "ERROR: Could not download latest update from $HttpFileStorage/$SCRIPTNAME!"
		exit 1
	fi
	md5cur=($(md5sum "$SCRIPTPATH"))
	md5new=($(md5sum "$SCRIPTPATH.updatecheck"))
	if [ "$md5cur" != "$md5new" ]; then
		echo "New version available - updating $SCRIPTNAME"
		if ! mv "$SCRIPTPATH.updatecheck" "$SCRIPTPATH" &>/dev/null; then
			echo "ERROR: Could not move $SCRIPTPATH.updatecheck to $SCRIPTPATH"
			exit 1
		fi
		if ! chmod 744 "$SCRIPTPATH" &>/dev/null; then
			echo "ERROR: could not chmod $SCRIPTPATH"
			exit 1
		fi
		echo "SUCCESS: Script successfully updated"
		bash "$SCRIPTPATH" "$@" updated; exitcode=$?
		exit $exitcode
	else
		echo "SUCCESS: Script is on the newest (latest) version"
		rm "$SCRIPTPATH.updatecheck"
	fi
else
	echo "DONE: Currently no script update available on $HttpFileStorage/$SCRIPTNAME"
fi

#
# MAIN FLOW
#

# Install NodeJS and NPM
# https://www.digitalocean.com/community/tutorials/how-to-install-node-js-on-ubuntu-22-04
if ! node -v &>/dev/null; then
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "Install NodeJS and NPM"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    curl -sL https://deb.nodesource.com/setup_18.x -o nodesource_setup.sh
    sudo bash nodesource_setup.sh
    sudo apt -y install nodejs
    rm nodesource_setup.sh
else
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "Update NodeJS and NPM"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    #apt -y update
    apt -y install nodejs
fi

# Install Apache2
if ! apache2 -v &>/dev/null; then
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "Install Apache2 HTTP Server"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    apt -y update
    apt -y install apache2
else
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "Update Apache2 HTTP Server"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    #apt -y update
    apt -y install apache2
fi

# Setup Apache2 proxy
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
echo "Configure Apache2 Proxy"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
APACHESYLICFG=$'
<Proxy *>
	 Order allow,deny
	 Allow from all
	 Require all granted
</Proxy>
AllowEncodedSlashes NoDecode
ProxyPreserveHost On
ProxyRequests off
AllowEncodedSlashes NoDecode
ProxyPass / http://localhost:8080/ nocanon
ProxyPassReverse / http://localhost:8080/ nocanon
'
echo "$APACHESYLICFG" 2>/dev/null 1>"/etc/apache2/conf-available/syli.conf"
a2enmod proxy
a2enmod proxy_http
a2enconf syli
sudo systemctl restart apache2

# Install api branch from synclink spec repo
# https://stackoverflow.com/questions/45958733/check-if-a-git-repo-exists-in-a-shell-script
if ! [ -d "synclink-spec" ]; then
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "Install SyncLink API Specification"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    git clone -b api --single-branch https://github.com/stereum-dev/synclink-spec.git
else
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "Update SyncLink API Specification"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    currdir="$PWD"
    cd synclink-spec
    git pull
    cd "$currdir"
fi

# Add cron job and run each 10 minutes
CRONCONT="*/10 * * * * root /bin/bash $SCRIPTPATH cron" # MUST END WITH NEWLINE!
if ! [ -f "$CRONFILE" ]; then
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "Add cron job"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    if ! echo "$CRONCONT" > "$CRONFILE"; then
        echo "ERROR: Could not add cron job!"; 
        exit 3
    fi
    echo "Cron job successfully added"
else
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "Update cron job"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
	md5cur=($(md5sum "$CRONFILE"))
    md5cur=$(trim "$md5cur")
	md5new=($(echo "$CRONCONT" | md5sum))
    md5new=$(trim "$md5new")
	if [ "$md5cur" != "$md5new" ]; then
        if ! echo "$CRONCONT" > "$CRONFILE"; then
            echo "ERROR: Could not update cron job!"; 
            exit 3
        fi
		echo "Cron job successfully updated"
    else
		echo "Cron job already up to date"
	fi
fi

# Run SyncLink API Specification (in background)
if [ "${1,,}" != "cron" ] || [ "${2,,}" = "updated" ]; then
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "Starting SyncLink API Specification"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    currdir="$PWD"
    pkill -f 'redocly' &>/dev/null
    cd synclink-spec
    npm install &>/dev/null
    nohup npm start &>/dev/null &
    cd "$currdir"
    myip=$(curl -s https://api.ipify.org)
    echo "SyncLink API Specification started on http://$myip"
    echo "OPERATION COMPLETE"
fi