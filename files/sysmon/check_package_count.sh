#!/bin/bash

if [ "$1" == "" ]; then
    echo "Count the number of packages available to upgrade"
    echo
    echo "Usage: $0 [WARN_COUNT]"
    echo
    echo "Example: $0 1 :  Count packages to upgrade. If 1 or more, send WARNING"
    exit 3
fi

WARN_COUNT=$1 # Threshold from which we send a WARNING
SEVERITY=${2:-Important} # Default severity to Critical if not specified

# Determine the OS type
if command -v apt >/dev/null 2>&1; then
    # Debian-based system
    PKG_LIST_FILE=/var/lib/apt-check-updates/list

    # Check the file age of PKG_LIST_FILE as a safety check
    # If PKG_LIST_FILE is too old, maybe the scripts to update that list didn't work as expected
    # Note that 93600 below is a number of seconds, that is 26 hours
    FILE_AGE_OUTPUT=$(/usr/bin/perl /usr/lib64/nagios/plugins/check_file_age -w 93600 -c 93600 -i -f $PKG_LIST_FILE)
    echo $FILE_AGE_OUTPUT | grep '^FILE_AGE OK:' > /dev/null
    FILE_AGE_OUTPUT_NOT_OK=$?
    if [ ! $FILE_AGE_OUTPUT_NOT_OK -eq 0 ]; then
        echo $FILE_AGE_OUTPUT
        exit 1
    fi

    # Get the list of packages to upgrade and the number of packages as RESULT
    LIST=$(cat $PKG_LIST_FILE)
    RESULT=$(echo $LIST | wc -w)

elif command -v yum >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then
    # RHEL-based system
    if command -v yum >/dev/null 2>&1; then
        PKG_MANAGER=yum
    else
        PKG_MANAGER=dnf
    fi

    # Get the list of packages to upgrade and the number of packages as RESULT using --sec-severity option
    LIST=$($PKG_MANAGER updateinfo list --sec-severity=$SEVERITY | awk 'NR>2 {print $3}')
    RESULT=$(echo "$LIST" | wc -w)

else
    echo "UNKNOWN - Package manager not found"
    exit 3
fi

STATE="OK"
status=0

if [ $RESULT -ge $WARN_COUNT ]; then
    STATE="WARNING"
    status=1
fi

echo "$STATE - $RESULT packages available to upgrade: $LIST | pkg_count=$RESULT;$WARN_COUNT;;;"
exit $status
