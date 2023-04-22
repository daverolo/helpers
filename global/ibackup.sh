#!/bin/bash
# -----------------------------------------------------------------------------
# What: Backup current folder to {iCloudDrive}/{FOLDERNAME}-YmdHis.zip on a Mac
# Link: wget https://raw.githubusercontent.com/daverolo/helpers/main/global/ibackup.sh
# Usage: bash ibackup.sh
# -----------------------------------------------------------------------------

# Vars
CURRENT_DIR="$PWD"
BACKUP_FILE_NAME="$(basename $CURRENT_DIR)_$(date '+%Y%m%d%H%M%S').zip"
BACKUP_FILE_PATH="$CURRENT_DIR/$BACKUP_FILE_NAME"
BACKUP_EXCL_PTTR="$(echo $BACKUP_FILE_NAME | rev | cut -d'_' -f2- | rev)*"

# ZIP current folder, exclude existing backups
zip -r ./$BACKUP_FILE_NAME . -x "$BACKUP_EXCL_PTTR" -x '*.DS_Store'

# Change to iCloud drive directory (you can not set this a variable for whatever reason) and then move the zip file
cd ~/Library/Mobile\ Documents/com~apple~CloudDocs
mv "$BACKUP_FILE_PATH" .
echo "Current directory successfully backed up to your iCloud Drive as $BACKUP_FILE_NAME"
