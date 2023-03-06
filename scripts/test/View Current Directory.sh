#!/bin/bash

### begin variables ###
# get username of currently logged in user
loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
homeDirectory="/Users/$loggedInUser/"
storage=".JamfStorage"
dockUpdate="dockUpdate.txt"
updateNow="0"
currentMonth=$( date +%B )
### end variables ###

### begin script ###
#move into their directory
cd $homeDirectory

# check if $storage directory already exists, otherwise create it.
if [ ! -d $storage ]; then
	echo "INFO: $storage does not exist, creating..."
	mkdir $storage
else
	echo "INFO: $storage exists!"
fi

# move into the storage directory
cd $storage

## At this point, we are now in /User/$loggedInUser/.JamfStorage.
# check if $dockUpdate already exists, otherwise create it, and setup formatting in file
if [ ! -f $dockUpdate ]; then
	echo "INFO: $dockUpdate does not exist, creating..."
	touch $dockUpdate

	# write to the file with some basic info
	echo "# This file contains the month the dock was last updated." >> $dockUpdate
	echo "lastUpdate=$currentMonth)">> $dockUpdate

	#since file was just created, this user's dock is incorrect.
	updateNow="1"
else
	echo "INFO: $dockUpdate exists!"
fi

# grab the last month the dock was updated
lastUpdate=$( grep "lastUpdate" dockUpdate.txt | awk -F"=" '{ print $2 }' )

# if the dock has never been set OR if the month is different, then set the dock
if [ $updateNow == "1" ] || [ $lastUpdate != $currentMonth]; then
	echo "INFO: Updating dock..."
	
	# Set up variables
	whoami="/usr/bin/whoami"
	echo="/bin/echo"
	sudo="/usr/bin/sudo"
	grep="/usr/bin/grep"
	ls="/usr/bin/ls"
	dockutil="/usr/local/bin/dockutil"
	killall="/usr/bin/killall"
	loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
	LoggedInUserHome="/Users/$loggedInUser"
	UserPlist=$LoggedInUserHome/Library/Preferences/com.apple.dock.plist

	##########################################################################################
	# Check if script is running as root
	##########################################################################################
	$echo

	if [ `$whoami` != root ]; then
	    $echo "[ERROR] This script must be run using sudo or as root. Exiting..."
	    exit 1
	fi

	##########################################################################################
	# Use Dockutil to Modify Logged-In User's Dock
	##########################################################################################
	$echo "----------------------------------------------------------------------"
	$echo "Dockutil script to modify logged-in user's Dock"
	$echo "----------------------------------------------------------------------"
	$echo "Current logged-in user: $loggedInUser"
	$echo "----------------------------------------------------------------------"
	$echo "Removing all Items from the Logged-In User's Dock..."
	$sudo -u $loggedInUser $dockutil --remove all --no-restart $UserPlist

	$echo "Creating New Dock..."
	$echo
	$echo "Adding \"Finder\"..."

	$echo "Adding \"System Preferences\"..."
	$sudo -u $loggedInUser $dockutil --add "/System/Applications/System Preferences.app" --no-restart $UserPlist

	$echo "Adding \"Google Chrome\"..."
	$sudo -u $loggedInUser $dockutil --add "/Applications/Google Chrome.app" --no-restart $UserPlist

	$echo "Adding \"Safari\"..."
	$sudo -u $loggedInUser $dockutil --add "/Applications/Safari.app" --no-restart $UserPlist

	$echo "Adding \"Firefox\"..."
	$sudo -u $loggedInUser $dockutil --add "/Applications/Firefox.app" --no-restart $UserPlist

	$echo "Adding \"Crestron AirMedia\"..."
	$sudo -u $loggedInUser $dockutil --add "/Applications/Crestron/Crestron AirMedia.app" --no-restart $UserPlist

	$echo "Adding \"JHU Self Service\"..."
	$sudo -u $loggedInUser $dockutil --add "/Applications/JHU Self Service.app" --no-restart $UserPlist

	$echo "Adding \"Documents\"..."
	$sudo -u $loggedInUser $dockutil --add "~/Documents" --section others --view auto --display folder --no-restart $UserPlist

	$echo "Adding \"Audio\"..."
	$sudo -u $loggedInUser $dockutil --add "/Volumes/Workshop/DockItems/Audio" --section others --view fan --display folder --no-restart $UserPlist

	$echo "Adding \"Graphics & Photos\"..."
	$sudo -u $loggedInUser $dockutil --add "/Volumes/Workshop/DockItems/Graphics & Photos" --section others --view fan --display folder --no-restart $UserPlist

	$echo "Adding \"Creative Code & Programming\"..."
	$sudo -u $loggedInUser $dockutil --add "/Volumes/Workshop/DockItems/Creative Code & Programming" --section others --view fan --display folder --no-restart $UserPlist

	$echo "Adding \"3D Design & Printing\"..."
	$sudo -u $loggedInUser $dockutil --add "/Volumes/Workshop/DockItems/3D Design & Printing" --section others --view fan --display folder --no-restart $UserPlist

	$echo "Adding \"Video\"..."
	$sudo -u $loggedInUser $dockutil --add "/Volumes/Workshop/DockItems/Video" --section others --view fan --display folder --no-restart $UserPlist

	$echo "Adding \"Office & Documents\"..."
	$sudo -u $loggedInUser $dockutil --add "/Volumes/Workshop/DockItems/Office & Documents" --section others --view fan --display folder --no-restart $UserPlist

	$echo "Adding \"Chat & Communication\"..."
	$sudo -u $loggedInUser $dockutil --add "/Volumes/Workshop/DockItems/Chat & Communication" --section others --view fan --display folder --no-restart $UserPlist

	$echo "Adding \"Bookit\"..."
	$sudo -u $loggedInUser $dockutil --add "/Volumes/Workshop/DockItems/webclips/DMC BookIt!.webloc" --section others --no-restart $UserPlist

	$echo "Adding \"DMC Knowledge Base\"..."
	$sudo -u $loggedInUser $dockutil --add "/Volumes/Workshop/DockItems/webclips/DMC Knowledge Base.webloc" --section others --no-restart $UserPlist

	$echo "Adding \"Hopkins Groups\"..."
	$sudo -u $loggedInUser $dockutil --add "/Volumes/Workshop/DockItems/webclips/HopkinsGroups.webloc" --section others --no-restart $UserPlist

	$echo "Restarting Dock..."
	$sudo -u $loggedInUser $killall Dock
else
	echo "INFO: Dock is up to date!"
fi
