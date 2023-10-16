#!/bin/bash

RC_OK=0
RC_CRITICAL=2
RC_UNKNOWN=3
OUTLIM=160

APC_CMD="/sbin/apcaccess"
MSG_POWERFAIL='running on batery'
MSG_OK='running on mains power'

STATUS=`$APC_CMD |grep STATUS | awk -F: '{ print $2 }'`
BCHARGE=`$APC_CMD |grep BCHARGE`
if [ $STATUS != 'ONLINE' ]; then
    TIMELEFT=`$APC_CMD |grep TIMELEFT`
    echo "CRITICAL: $MSG_POWERFAIL, $BCHARGE, $TIMELEFT"
    exit $RC_CRITICAL
else
    echo "OK: $MSG_OK, $BCHARGE"
    exit $RC_OK
fi

