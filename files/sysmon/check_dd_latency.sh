#!/bin/bash

if [ "$1" == "" ];then
echo "Measure the time/latency to write a file to disk"
echo
echo "Usage: $0 TARGETDIR [FILE_SIZE - MB] [WARN_SEC] [CRIT_SEC]"
echo
echo "Example: $0 /tmp 100 1.75 5 : Write 100M to /tmp, report Warning after 1.75 sec, Critical after 5 sec"
exit
fi

TARGETDIR=$1 # part of the fs we want to check
FILE_SIZE=$2
WARN_SEC=$3
CRIT_SEC=$4
FILENAME=zero.img.$$ # $$ adds the PID to create a random name
SOURCE=/dev/zero

if [ "$FILE_SIZE" != "" ]; then
  SIZE=${FILE_SIZE}M
else
  SIZE=1M
fi

# %E is Elapsed real (wall clock) time used by the process, in [hours:]minutes:seconds
MYTIME=`/usr/bin/time -f "\t%E" dd if=$SOURCE of=$TARGETDIR/$FILENAME bs=$SIZE count=1 oflag=dsync 2>&1  |tail -n 1`

# get result in seconds
RESULT=`echo $MYTIME | cut -d ':' -f 2`

STATE="OK"
status=0

if [ "$WARN_SEC" != "" ]; then
  if [ `echo "$RESULT >= $WARN_SEC" | bc -l` == "1" ]; then
    STATE="WARNING"
    status=1
  fi
fi

if [ "$CRIT_SEC" != "" ]; then
  if [ `echo "$RESULT >= $CRIT_SEC" | bc -l` == "1" ]; then
    STATE="CRITICAL"
    status=2
  fi
fi

echo "$STATE - $RESULT to write $SIZE | latency_$SIZE=$RESULT;$WARN_SEC;$CRIT_SEC"

rm -f $TARGETDIR/$FILENAME
exit $status
