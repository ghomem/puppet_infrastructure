#!/bin/bash

if [ "$1" == "" ];then
echo "Count the number of packages available to upgrade"
echo
echo "Usage: $0 [WARN_COUNT]"
echo
echo "Example: $0 1 :  Count packages to upgrade . If 1 or more, send WARNING "
exit 3
fi

WARN_COUNT=$1 # Threshold from which we send an WARNING 
PKG_LIST_FILE=/var/lib/apt-check-updates/list

# check the file age of PKG_LIST_FILE as a safety check
# if PKG_LIST_FILE is too old, maybe the scripts to update that list didn't work as expected
# please note that 93600 below is a number of seconds, that is 26 hours
FILE_AGE_OUTPUT=`/usr/bin/perl /usr/lib64/nagios/plugins/check_file_age -w 93600 -c 93600 -i -f $PKG_LIST_FILE`
echo $FILE_AGE_OUTPUT | grep '^FILE_AGE OK:' > /dev/null
FILE_AGE_OUTPUT_NOT_OK=$?
if [ ! $FILE_AGE_OUTPUT_NOT_OK -eq 0 ]; then
  echo $FILE_AGE_OUTPUT
  exit 1
fi

# get list of packages to upgrade and number of packages as RESULT
LIST=`cat $PKG_LIST_FILE`
RESULT=`echo $LIST | wc -w`

STATE="OK"
status=0

if [ $RESULT -ge $WARN_COUNT ]; then
  STATE="WARNING"
  status=1
fi

echo "$STATE - $RESULT packages available to upgrade: $LIST | pkg_count=$RESULT;$WARN_COUNT;;;"
exit $status
