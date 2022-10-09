#!/bin/bash
# SyncLink Api Spec Setup/Update Script (daverolo/synclink-api-spec-update.sh):
# https://gist.github.com/daverolo/cf0cdc695731db71260c876f408ae265
# wget -O update.sh <RAWURL>
# bash update.sh

# Move to home dir
cd ~

# Install NodeJS and NPM
# https://www.digitalocean.com/community/tutorials/how-to-install-node-js-on-ubuntu-22-04
if ! node -v &>/dev/null; then
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "Install NodeJS and NPM"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    curl -sL https://deb.nodesource.com/setup_18.x -o nodesource_setup.sh
    sudo bash nodesource_setup.sh
    sudo apt -y install nodejs
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

# Run SyncLink API Specification (in background)
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