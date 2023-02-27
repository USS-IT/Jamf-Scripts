#!/bin/bash

# search the volumes folder and keep all the workshop and project drives.
driveList=`ls /Volumes | grep -e Workshop -e Project`

# iterate over driveList
for value in ${driveList}
do
	# unmount the current workshop drive
	diskutil unmount force '/Volumes/'${value} 2> /dev/null

    # remove the symbolic link to this drive
    rm -rf '/Volumes/'${value} 2> /dev/null
done
