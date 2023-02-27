#!/bin/bash
loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

if groups "$loggedInUser" | grep -q -w admin
then
echo "admin"
else
echo "not admin"
fi