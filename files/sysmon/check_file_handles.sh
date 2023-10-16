#!/bin/bash

# 2019.11.13 , Joao Clemente , v1.0 : Report the kernel file handle values

TMP_FILE=/tmp/check_file_handle.$$ # $$ adds the PID to create a random name

cat /proc/sys/fs/file-nr > $TMP_FILE
F_ALL=`cat $TMP_FILE`
F_USED=`cat $TMP_FILE | awk '{ print $1 }'`
F_UNUSED=`cat $TMP_FILE | cut -f 2`
F_MAX=`cat $TMP_FILE | cut -f 3`

STATE="OK"
status=0

echo "$STATE - `echo -n $F_ALL` | f_handle_used=$F_USED;;;;$F_MAX"

rm -f $TMP_FILE
exit $status
