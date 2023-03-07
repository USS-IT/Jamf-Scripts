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
homeDirectory="/Users/$loggedInUser"

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
	# search the volumes folder and keep all the workshop and project drives.
	local driveList=$( ls /Volumes | grep -e Workshop -e Project )

	# iterate over driveList
	for value in ${driveList}
	do
		# unmount the current workshop drive
		local error=$(diskutil unmount force "/Volumes/${value}" 1> /dev/null)
		log "ERROR" "$error"
    
	    # remove the symbolic link to this drive
	    rm -rf "/Volumes/${value}" 1> /dev/null
	done
	
	log "INFO" "Volumes successfully removed!"
}

##
# Function to mount workshop drive as current user if admin or as 
# guest if not admin.
##
mountWorkshop() {
	#check if current user is an admin
	if [ $( groups "$loggedInUser" | grep -qw "admin") ]; then
		log "INFO" "Attemping to mount Workshop as current user!"
		
		#mount the project drive and project drive as the current user.
		open 'smb://'$loggedInUser':@HW-DMC-HIPPO.win.ad.jhu.edu/Workshop'
	
	else
		log "INFO" "Attempting to mount Workshop as guest!"
		
		# mount only the workshop drive as a gust
		open 'smb://guest:@HW-DMC-HIPPO.win.ad.jhu.edu/Workshop'
	fi
	
	local driveMounted=0
	
	# while drive is not mounted, check again until mounted.
	while (($driveMounted == 0))
	do
		local driveMounted=$( ls /Volumes | grep -e Workshop -c)
		#log "VAR" "driveMounted=$driveMounted"
		sleep 2
	done
	
	log "INFO" "Successfully mounted Workshop drive!"
}


###
# Small helper function to make sure the storage directory already exists.
# If it does not exist, this function creates it.
###
checkStorageDirectory () {
	# check if $storage directory already exists, otherwise create it.
	if [ ! -d "$homeDirectory/$storage" ]; then
		log "INFO" "$storage does not exist, creating..."
		mkdir "$homeDirectory/$storage"
	else
		log "INFO" "$storage exists!"
	fi
}

###
# Small helper function to make sure the storage file already exists.
# If it does not exist, this function creates and populates it.
checkStorageFile() {
	## At this point, we are now in /User/$loggedInUser/.JamfStorage.
	# check if $dockUpdate already exists, otherwise create it, and setup formatting in file
	if [ ! -f "$homeDirectory/$storage/$dockUpdate" ]; then
		log "INFO" "$dockUpdate does not exist, creating..."
		touch "$homeDirectory/$storage/$dockUpdate"

		# write to the file with some basic info
		echo "# This file contains the month the dock was last updated." >> "$homeDirectory/$storage/$dockUpdate"
		echo "lastUpdate=$currentMonth">> "$homeDirectory/$storage/$dockUpdate"

		#since file was just created, this user's dock is incorrect.
		return 1
	else
		log "INFO" "$dockUpdate exists!"
		return 0
	fi
}

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
	
	# Check if script is running as root
	if [ `$whoami` != root ]; then
	    log "ERROR" "updateDock: This script must be run using sudo or as root. Exiting..."
	    exit 5
	fi
	
	local OS=$(sw_vers -productVersion)

	###
	# Use Dockutil to Modify Logged-In User's Dock
	###
	log "INFO" "Removing all Items from the Logged-In User's Dock..."
	$sudo -u $loggedInUser $dockutil --remove all --no-restart $UserPlist

	log "INFO" "Creating new dock..."
	
	# In macOS Ventura, System Preferences was renamed to System Settings. We perform an OS version
	# check here to make sure we add the correct one to the dock
	if (($OS <= 13)); then
		log "INFO" "macOS Monterey or older detected, adding System Preferences."
		$sudo -u $loggedInUser $dockutil --add "/System/Applications/System Preferences.app" --no-restart $UserPlist
	else
		log "INFO" "macOS Ventura or newer detected, adding System Preferences."
		$sudo -u $loggedInUser $dockutil --add "/System/Applications/System Settings.app" --no-restart $UserPlist
	fi
	
	$sudo -u $loggedInUser $dockutil --add "/Applications/Google Chrome.app" --no-restart $UserPlist
	$sudo -u $loggedInUser $dockutil --add "/Applications/Safari.app" --no-restart $UserPlist
	$sudo -u $loggedInUser $dockutil --add "/Applications/Firefox.app" --no-restart $UserPlist
	$sudo -u $loggedInUser $dockutil --add "/Applications/Crestron/Crestron AirMedia.app" --no-restart $UserPlist
	$sudo -u $loggedInUser $dockutil --add "/Applications/JHU Self Service.app" --no-restart $UserPlist
	$sudo -u $loggedInUser $dockutil --add "~/Documents" --section others --view auto --display folder --no-restart $UserPlist
	$sudo -u $loggedInUser $dockutil --add "$homeDirectory/$storage/DockItems/Audio" --section others --view fan --display folder --no-restart $UserPlist
	$sudo -u $loggedInUser $dockutil --add "$homeDirectory/$storage/DockItems/Graphics & Photos" --section others --view fan --display folder --no-restart $UserPlist
	$sudo -u $loggedInUser $dockutil --add "$homeDirectory/$storage/DockItems/Creative Code & Programming" --section others --view fan --display folder --no-restart $UserPlist
	$sudo -u $loggedInUser $dockutil --add "$homeDirectory/$storage/DockItems/3D Design & Printing" --section others --view fan --display folder --no-restart $UserPlist
	$sudo -u $loggedInUser $dockutil --add "$homeDirectory/$storage/DockItems/Video" --section others --view fan --display folder --no-restart $UserPlist
	$sudo -u $loggedInUser $dockutil --add "$homeDirectory/$storage/DockItems/Office & Documents" --section others --view fan --display folder --no-restart $UserPlist
	$sudo -u $loggedInUser $dockutil --add "$homeDirectory/$storage/DockItems/Chat & Communication" --section others --view fan --display folder --no-restart $UserPlist
	$sudo -u $loggedInUser $dockutil --add "$homeDirectory/$storage/DockItems/webclips/DMC BookIt!.webloc" --section others --no-restart $UserPlist
	$sudo -u $loggedInUser $dockutil --add "$homeDirectory/$storage/DockItems/webclips/DMC Knowledge Base.webloc" --section others --no-restart $UserPlist
	$sudo -u $loggedInUser $dockutil --add "$homeDirectory/$storage/DockItems/webclips/HopkinsGroups.webloc" --section others --no-restart $UserPlist

	log "INFO" "Restarting Dock..."
	$sudo -u $loggedInUser $killall Dock
	
	log "INFO" "Dock update complete!"
}

###
# Helper function to copy the DockIcons from the Workshop drive locally.
# TODO: rather than having the dock icons stored in each user's profile, copy them elsewhere for all to have access to.
###
copyDockItems() {
	#delete folder if it already exists.
	log "INFO" "Deleting user's DockItems folder"
	rm -rf $homeDirectory/$storage/DockItems
	
	#copy over the DockItems folder from the Workshop drive to the user's local .JamfStorage folder.
	log "INFO" "Copying DockItems"
	cp -r /Volumes/Workshop/DockItems/ $homeDirectory/$storage/DockItems
}


handleDock () {
	# begin variables
	local storage=".JamfStorage"
	local dockUpdate="dockUpdate.txt"
	local currentMonth=$( date +%B )
	# end variables

	# move into their directory
	#cd $homeDirectory

	# check to make sure the storage directory already exists and if not create it.
	checkStorageDirectory

	# move into the storage directory
	#cd $storage

	# check to make sure the $dockUpdate file exists and if not create it.
	checkStorageFile
	local updateNow=$?
	#log "VAR" "updateNow=$updateNow"

	# grab the last month the dock was updated
	local lastUpdate=$( grep "lastUpdate" dockUpdate.txt | awk -F"=" '{ print $2 }' )

	# if the dock has never been set OR if the month is different, then set the dock
	if [ $updateNow == "1" ] || [ $lastUpdate != $currentMonth ]; then
		#log "VAR" "lastUpdate=$lastUpdate"
		#log "VAR" "currentMonth=$currentMonth"
		copyDockItems
		updateDock
	else
		log "INFO" "Dock is up to date!"
	fi
}

###
# Main function
###
main () {
	log "INFO" "Calling removeVolumes."
	removeVolumes
	
	log "INFO" "Calling mountWorkshop."
	mountWorkshop
	
	log "INFO" "Calling handleDock."
	handleDock
	
	log "INFO" "Script complete, exit 0."
	exit 0
}

# call the main function
main