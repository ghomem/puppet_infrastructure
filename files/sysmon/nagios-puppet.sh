#!/bin/bash

RC_OK=0
RC_CRITICAL=2
RC_UNKNOWN=3
OUTLIM=160

TEMP=`puppet agent --test 2>1`
RC=$?
# this removes the newlines, we limit the ouput to avoid surprises
OUTPUT=`echo $TEMP | head -c $OUTLIM`


# handle different types of exit codes
if [ $RC -eq 1 ]; then
  echo $OUTPUT |grep "agent_catalog_run.lock" >/dev/null
  RC2=$?
  if [ $RC2 -eq 0 ]; then
    echo "UNKNOWN: exit code $RC $OUTPUT"
    exit $RC_UNKNOWN
  else
    echo "CRITICAL: exit code $RC $OUTPUT"
    exit $RC_CRITICAL
  fi
else 
  if [ $RC -gt 2 ]; then
    echo "CRITICAL: exit code $RC $OUTPUT"
    exit $RC_CRITICAL
  fi
fi

# normal case
echo "OK: exit code $RC $OUTPUT"
exit $RC_OK
