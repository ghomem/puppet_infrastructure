#!/bin/bash

RC_ERR=1
UPDATE_CMD="/usr/bin/yum update -y"
SURFACE="openssh-server openssh nginx openssl ca-certificates httpd"

if [ -z "$SURFACE" ]; then
  echo "The list must NOT be empty"
  exit $RC_ERR
fi

# with filtered output
for p in $SURFACE; do
  $UPDATE_CMD $p |grep "Updating" |grep "/" | tr -s ' ' |cut -d ' ' -f 2-4
  # get return code from yum, not grep
  RC=${PIPESTATUS[0]}
  if [ $RC -ne 0 ]; then
    echo "error updating package $p"
  fi
done

exit 0
