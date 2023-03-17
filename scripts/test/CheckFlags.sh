#!/bin/bash

checkFlags() {
	local OPTIND
	while getopts "r" opt; do
	  case "$opt" in
	    r)
	      echo "-a was triggered, Parameter: $OPTARG" >&2
	      ;;
	    \?)
	      echo "Invalid option: -$OPTARG" >&2
	      exit 1
	      ;;
	    :)
	      echo "Option -$OPTARG requires an argument." >&2
	      exit 1
	      ;;
	  esac
	done
	shift $((OPTIND-1))
}

checkFlags "$@"