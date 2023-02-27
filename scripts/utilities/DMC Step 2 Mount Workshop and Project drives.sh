#!/bin/bash
# sleep for 4 seconds to make sure previous script is totally done
sleep 5

loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

#check if current user is an admin
if groups $loggedInUser | grep -q -w admin
then
#mount the project drive and project drive as the current user.
open 'smb://'$loggedInUser':@HW-DMC-HIPPO.win.ad.jhu.edu/Project'

driveList=`ls /Volumes | grep -q -w Project`

until [ $driveList ]
do
	driveList=`ls /Volumes | grep -e Project`
done

sleep 5

#mount the workshop drive and project drive as the current user.
open 'smb://'$loggedInUser':@HW-DMC-HIPPO.win.ad.jhu.edu/Workshop'

sleep 5


else
# mount only the workshop drive as a gust
open 'smb://guest:@HW-DMC-HIPPO.win.ad.jhu.edu/Workshop'
fi

