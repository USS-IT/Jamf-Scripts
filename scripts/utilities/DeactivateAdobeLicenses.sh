#!/bin/bash

###
# Global Variables
###
toolkitPath="/Volumes/tempAdobe"
toolkitCommand="$toolkitPath/adobe-licensing-toolkit"
toolkitFailure="Operation Failed"
toolkitSuccess="Operation Succeeded"
toolkitOutput=$($toolkitCommand --deactivate | grep "$toolkitFailure")

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
# Simple function to attempt to deactivate
###
deactivateLicense () {
  local output="$toolkitOutput"
  if [ "$output" == "$toolkitFailure" ]; then
    log "WARNING" "Deactivating licenses failed, perhaps none were present."

  elif [ "$output" == "$toolkitSuccess" ]; then
    log "INFO" "Deactivating licenses succeeded."

  else
    log "ERROR" "Unknown error was thrown when attempting to deactivate licenses, exit 10."
    exit 10
  fi
}

main () {

  deactivateLicense

	log "INFO" "Script complete, exit 0."
	exit 0
}

# call the main function
main "$@"

#rm -rf /Volumes/tempAdobe/