#!/bin/bash

# 2019.11.01 , Joao Clemente , v1.0 : Count the different status reported by netstat. No alarming is sent in this version

#if [ "$1" == "" ];then
#echo "Count all conection status reported by netstat"
#echo
#echo "Usage: $0 "
#exit
#fi

TMP_FILE=/tmp/netstat.$$ # $$ adds the PID to create a random name

netstat -an > $TMP_FILE
NETSTAT_LEN=`cat $TMP_FILE | wc -l`
TCP_LISTEN=`cat $TMP_FILE | grep tcp  | grep LISTEN | wc -l`
TCP_WAIT=`cat $TMP_FILE | grep tcp  | grep TIME_WAIT | wc -l`
TCP_ESTAB=`cat $TMP_FILE | grep tcp  | grep ESTABLISHED | wc -l`
TCP_SYN=`cat $TMP_FILE | grep tcp  | grep SYN | wc -l`
UNIX_LISTEN=`cat $TMP_FILE | grep unix | grep LISTEN | wc -l`
UNIX_CONN=`cat $TMP_FILE | grep unix | grep CONNECTED | wc -l`

STATE="OK"
status=0

echo "$STATE - $NETSTAT_LEN netstat lines | tcp_listen=$TCP_LISTEN tcp_wait=$TCP_WAIT tcp_established=$TCP_ESTAB tcp_syn=$TCP_SYN unix_listen=$UNIX_LISTEN unix_connected=$UNIX_CONN"

rm -f $TMP_FILE
exit $status
