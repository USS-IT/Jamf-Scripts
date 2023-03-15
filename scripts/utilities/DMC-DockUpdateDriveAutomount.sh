#!/bin/bash

###########
# This script performs three actions. 
#
# First, it removes any existing volumes with the names "Workshop" or "Project".
#
# Second, we check if the currently logged in user is admin. If they are an admin,
# we mount the Workshop drive as their user (it prompts for credentials). Otherwise,
# it mounts the Workshop drive as the guest user.
#
# Third, we perform a dock update if specific pre-requistes are met. If this is the
# first time a user has logged in or if the dock has not been updated for more than
# a month, we perform a dock update. Otherwise, no dock update is performed.
###########

###
# Global Variables
###
loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
loggedInUserID=$(id -u "$loggedInUser")
homeDirectory="/Users/$loggedInUser"
jamfStorage=".JamfStorage"
dockHistory="dockHistory.txt"
dockItems="DockItems"
jamfStoragePath="$homeDirectory/$jamfStorage"
dockHistoryPath="$jamfStoragePath/$dockHistory"
dockItemsPath="$jamfStoragePath/$dockItems"
loopTimeout=30
mountPoint="/Volumes/.mntpoint"
workshopMountPoint="$mountPoint/Workshop"
projectMountPoint="$mountPoint/Project"
forcedDockUpdate="0"

###
# A simple logging function that prints to screen the passed type and message.
###
log () {
	local code=$1
	local message=$2
	
	if [ ! -z "$message" ]; then
		echo "$code: $message"
	fi
}

###
# This function unmounts all Workshop and Project drives and removes their
# system links as well.
###
removeVolumes () {
	
	if [ -d "$mountPoint" ]; then
		log "INFO" "$mountPoint exists! Removing any existing mount points from it."
		
		local driveList=$( ls $mountPoint | grep -e Workshop -e Project )
	
		# iterate over driveList
		for value in ${driveList}
		do
			# unmount the drive
			local error=$(diskutil unmount force "$mountPoint/${value}" 1> /dev/null)
			log "ERROR" "$error"
    
	    	# remove the symbolic link to this drive
	    	rm -rf "$mountPoint/${value}" 1> /dev/null
		done
	
	else
		log "INFO" "mountPoint does not exist! creating..."
		mkdir $mountPoint
	fi
	
	
	log "INFO" "Removing any existing volumes previous mapped manually."
	local driveList=$( ls /Volumes | grep -e Workshop -e Project )

	# iterate over driveList
	for value in ${driveList}
	do
		# unmount the drive
		local error=$(diskutil unmount force "/Volumes/${value}" 1> /dev/null)
		log "ERROR" "$error"

    	# remove the symbolic link to this drive
    	rm -rf "/Volumes/${value}" 1> /dev/null
	done
	
	log "INFO" "Volumes successfully removed!"
	
}

###
# Function to mount workshop drive as current user if admin or as 
# guest if not admin.
###
mountWorkshopAsGuest() {
	log "INFO" "Attempting to mount Workshop as guest!"
	
	# create the mount point
	mkdir "$workshopMountPoint"
	
	# mount the workshop drive as a gust
	# using mount_smbfs allows us to mount the drive without Finder opening up everytime (very annoying)
	mount_smbfs "smb://guest:@HW-DMC-HIPPO.win.ad.jhu.edu/Workshop" "$workshopMountPoint"
	
	waitForWorkshopMount
}

###
# Short loop that waits to for Workshop mounting procedure to complete before contiuing.
###
waitForWorkshopMount() {
	local driveMounted=0
	
	# while drive is not mounted, check again until mounted or timeout runs out
	# timeout is set to 60 seconds.
	while (($driveMounted == 0)) && (($loopTimeout > 0))
	do
		local driveMounted=$( ls $mountPoint | grep -e Workshop -c)
		#log "VAR" "driveMounted=$driveMounted"
		sleep 2
		loopTimeout=$((loopTimeout--))
	done
	
	log "INFO" "Successfully mounted Workshop drive!"
}

###
# Short loop that waits to for Project mounting procedure to complete before contiuing.
###
waitForProjectMount() {
	local driveMounted=0
	
	# while drive is not mounted, check again until mounted or timeout runs out
	# timeout is set to 60 seconds.
	while (($driveMounted == 0)) && (($loopTimeout > 0))
	do
		local driveMounted=$( ls /Volumes | grep -e Project -c)
		#log "VAR" "driveMounted=$driveMounted"
		sleep 2
		loopTimeout=$((loopTimeout--))
	done
	
	log "INFO" "Successfully mounted Project drive!"
}


###
# Small helper function to make sure the storage directory already exists.
# If it does not exist, this function creates it.
###
checkStorageDirectory () {
	# check if $storage directory already exists, otherwise create it.
	if [ ! -d "$jamfStoragePath" ]; then
		log "INFO" "$jamfStorage does not exist, creating..."
		mkdir "$jamfStoragePath"
	else
		log "INFO" "$jamfStorage exists!"
	fi
}

###
# Small helper function to make sure the storage file already exists.
# If it does not exist, this function creates and populates it.
###
checkStorageFile() {
	## At this point, we are now in /User/$loggedInUser/.JamfStorage.
	# check if $dockUpdate already exists, otherwise create it, and setup formatting in file
	if [ ! -f "$dockHistoryPath" ]; then
		log "INFO" "$dockHistory does not exist, creating..."
		touch "$dockHistoryPath"

		# write to the file with some basic info
		echo "# This file contains the month the dock was last updated." >> "$dockHistoryPath"
		echo "lastUpdate=$currentMonth" >> "$dockHistoryPath"

		#since file was just created, this user's dock is incorrect.
		return 1
	else
		log "INFO" "$dockHistory exists!"
		return 0
	fi
}

###
# Performs Dock setup using dockutil.
# Note: If we cd to any other directory before this, THIS WILL FAIL (learned the hard way).
###
updateDock() {
	# Set up variables
	export PATH=/usr/bin:/bin:/usr/sbin:/sbin
	local whoami="/usr/bin/whoami"
	local echo="/bin/echo"
	local sudo="/usr/bin/sudo"
	local grep="/usr/bin/grep"
	local ls="/usr/bin/ls"
	local dockutil="/usr/local/bin/dockutil"
	local killall="/usr/bin/killall"
	local UserPlist="$homeDirectory/Library/Preferences/com.apple.dock.plist"
	local OS=$(sw_vers -productVersion)
	
	# Check if script is running as root
	if [ `$whoami` != root ]; then
	    log "ERROR" "updateDock: This script must be run using sudo or as root, exit 5"
	    exit 5
	fi

	# remove existing dock
	log "INFO" "Removing all Items from the Logged-In User's Dock..."
	$sudo -u $loggedInUser $dockutil --remove all --no-restart $UserPlist 1> /dev/null

	log "INFO" "Creating new dock..."
	
	# In macOS Ventura, System Preferences was renamed to System Settings. We perform an OS version
	# check here to make sure we add the correct one to the dock
	if (( $(echo "$OS 13" | awk '{print ($1 < $2)}') )); then
		log "INFO" "macOS Monterey or older detected, adding System Preferences."
		$sudo -u $loggedInUser $dockutil --add "/System/Applications/System Preferences.app" --no-restart $UserPlist 1> /dev/null
	else
		log "INFO" "macOS Ventura or newer detected, adding System Settings."
		$sudo -u $loggedInUser $dockutil --add "/System/Applications/System Settings.app" --no-restart $UserPlist 1> /dev/null
	fi
	
	# add new dock icons.
	# TODO convert these commands into single command with array of items to be added.
	$sudo -u $loggedInUser $dockutil --add "/Applications/Google Chrome.app" --no-restart $UserPlist 1> /dev/null
	$sudo -u $loggedInUser $dockutil --add "/Applications/Safari.app" --no-restart $UserPlist 1> /dev/null
	$sudo -u $loggedInUser $dockutil --add "/Applications/Firefox.app" --no-restart $UserPlist 1> /dev/null
	$sudo -u $loggedInUser $dockutil --add "/Applications/Crestron/Crestron AirMedia.app" --no-restart $UserPlist 1> /dev/null
	$sudo -u $loggedInUser $dockutil --add "/Applications/JHU Self Service.app" --no-restart $UserPlist 1> /dev/null
	$sudo -u $loggedInUser $dockutil --add "~/Documents" --section others --view auto --display folder --no-restart $UserPlist 1> /dev/null
	$sudo -u $loggedInUser $dockutil --add "$dockItemsPath/Audio" --section others --view fan --display folder --no-restart $UserPlist 1> /dev/null
	$sudo -u $loggedInUser $dockutil --add "$dockItemsPath/Graphics & Photos" --section others --view fan --display folder --no-restart $UserPlist 1> /dev/null
	$sudo -u $loggedInUser $dockutil --add "$dockItemsPath/Creative Code & Programming" --section others --view fan --display folder --no-restart $UserPlist 1> /dev/null
	$sudo -u $loggedInUser $dockutil --add "$dockItemsPath/3D Design & Printing" --section others --view fan --display folder --no-restart $UserPlist 1> /dev/null
	$sudo -u $loggedInUser $dockutil --add "$dockItemsPath/Video" --section others --view fan --display folder --no-restart $UserPlist 1> /dev/null
	$sudo -u $loggedInUser $dockutil --add "$dockItemsPath/Office & Documents" --section others --view fan --display folder --no-restart $UserPlist 1> /dev/null
	$sudo -u $loggedInUser $dockutil --add "$dockItemsPath/Chat & Communication" --section others --view fan --display folder --no-restart $UserPlist 1> /dev/null
	$sudo -u $loggedInUser $dockutil --add "$dockItemsPath/webclips/DMC BookIt!.webloc" --section others --no-restart $UserPlist 1> /dev/null
	$sudo -u $loggedInUser $dockutil --add "$dockItemsPath/webclips/DMC Knowledge Base.webloc" --section others --no-restart $UserPlist 1> /dev/null
	$sudo -u $loggedInUser $dockutil --add "$dockItemsPath/webclips/HopkinsGroups.webloc" --section others --no-restart $UserPlist 1> /dev/null

	# restart dock task
	log "INFO" "Restarting Dock..."
	$sudo -u $loggedInUser $killall Dock 1> /dev/null
	
	log "INFO" "Dock update complete!"
}

###
# Helper function to copy the DockIcons from the Workshop drive locally.
# TODO: rather than having the dock icons stored in each user's profile, copy them elsewhere for all to have access to.
###
copyDockItems() {
	#delete folder if it already exists.
	log "INFO" "Deleting user's DockItems folder"
	rm -rf "$dockItemsPath"
	
	#copy over the DockItems folder from the Workshop drive to the user's local .JamfStorage folder.
	log "INFO" "Copying DockItems"
	cp -r "$workshopMountPoint/DockItems/" "$dockItemsPath"
}

###
# Performs various checks for local storage and determines where or not dock needs updating.
###
handleDock () {
	# begin variables
	local currentMonth=$( date +%B )
	# end variables

	# check to make sure the storage directory already exists and if not create it.
	checkStorageDirectory

	# check to make sure the $dockUpdate file exists and if not create it.
	checkStorageFile
	local updateNow=$?
	#log "VAR" "updateNow=$updateNow"

	# grab the last month the dock was updated
	local lastUpdate=$( grep "lastUpdate" $dockHistoryPath | awk -F"=" '{ print $2 }' )

	# if the dock has never been set OR if the month is different, then set the dock
	if [ $updateNow == "1" ] || [ $forcedDockUpdate == "1" ] || [ $lastUpdate != $currentMonth ]; then
		#log "VAR" "lastUpdate=$lastUpdate"
		#log "VAR" "currentMonth=$currentMonth"
		copyDockItems
		updateDock
	else
		log "INFO" "Dock is up to date!"
	fi
}

###
# Checks if user is admin, and mounts Workshop as current user if they are admin.
###
checkIfAdmin () {
	# check if current user is an admin
	if [ $( groups $loggedInUser | tr " " "\n" | grep -w "admin") ]; then
		log "INFO" "Current user is admin! Unmounting guest Workshop drive!"
		removeVolumes
		
		log "INFO" "Attemping to mount Project and Workshop as current user!"

		# mount the project drive and workshop drive as the current user.
		# due to credential requirement, we must use open rather than
		# the superior mount_smbfs
		open "smb://$loggedInUser:@HW-DMC-HIPPO.win.ad.jhu.edu/Project"
		waitForProjectMount
		
		# we don't need to wait for workshop to mount since it won't prompt for credentials
		open "smb://$loggedInUser:@HW-DMC-HIPPO.win.ad.jhu.edu/Workshop"

	else
		log "INFO" "Current user is not admin."
	fi
}

#TODO update these notification functions to use jamfHelper or terminal-notifier

###
# Displays a simple notification notifying the user that the dock is updating.
###
startingNotification() {
	launchctl asuser "$loggedInUserID" osascript <<EOD
		display notification "Updating your dock. Please wait a moment." with title "DMC Dock Update"
		
		delay 5
EOD
#Note: EOD cannot be indented to properly exit from osascript.
}

###
# Displays a simple notification notifying the user that the dock update is complete.
###
completeNotification() {
	launchctl asuser "$loggedInUserID" osascript <<EOD
		display notification "Dock update complete!" with title "DMC Dock Update"
		
		delay 5
EOD
#Note: EOD cannot be indented to properly exit from osascript.
}

###
# Checks for "-u" flag to force a dock update if run via command line.
# Also checks for "update" param if run through jamf
###
checkFlags() {
	local OPTIND
	
	while getopts ":u" flag
	do
		case "$flag" in
			u)
				forcedDockUpdate="1"
				log "INFO" "Dock update forced!";;
			*)
				log "ERROR" "Invalid arugment passed: -$OPTARG, exit 10"
				exit 10;
				;;
		esac
	done
	shift $((OPTIND-1))
	
	if [ ! -z $4] && [$4 = "update"]; then
		forcedDockUpdate="1"
		log "INFO" "Dock update forced!"
	fi
	
}

###
# Main function
###
main () {
	startingNotification
	
	checkFlags "$@"
	
	removeVolumes
	
	mountWorkshopAsGuest
	
	handleDock
	
	checkIfAdmin
	
	completeNotification
	
	log "INFO" "Script complete, exit 0."
	exit 0
}

# call the main function
main "$@"