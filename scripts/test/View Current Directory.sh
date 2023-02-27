#!/bin/bash

### begin variables ###
# get username of currently logged in user
loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
homeDirectory="/Users/$loggedInUser/"
storage=".JamfStorage"
dockUpdate="dockUpdate.txt"
updateNow="0"
### end variables ###

### begin script ###
#move into their directory
cd $homeDirectory

# check if $storage directory already exists, otherwise create it.
if [ ! -d $storage ]; then
	echo "INFO: $storage does not exist, creating..."
	mkdir $storage
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
	echo "LastUpdate=$(date +%B)">> $dockUpdate

	#since file was just created, this user's dock is incorrect.
	$updateNow=1

fi

# TODO: checks and part for when file does exist already. If month is different, run update