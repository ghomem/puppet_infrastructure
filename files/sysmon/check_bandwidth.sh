#!/bin/bash

# 2019.09.17, Joao Clemente : Code cleanup , API change : Removed deprecated parameters ( first two ); Removed unneeded PID file detection; Added interface check and listing; Improved parameter detection
# 2019.09.05, Joao Clemente : Big code cleanup ; Removed Cisco support and corrected metrics output
# 2019.08.08, Joao Clemente : Modified output to remove display of start/end bit counter
# Based on https://exchange.nagios.org/directory/Plugins/Network-Connections%2C-Stats-and-Bandwidth/Check-interface-bandwidth/details with significant modification
# to solve https://issues.moosh.pt/view.php?id=132

INTERVAL="1"  # update interval in seconds

# Check if enough parameters were provided
if [ -z "$1" ] || [ -z "$5" ] ; then
        echo
        echo "usage  : $0 interface_name sample_time warning_mbit/s critical_mbit/s total_mbit/s;" 
        echo "example: $0 eth0 15 80 90 100"
        echo
        exit
fi

IF=$1
sec=$2
warn=$3
crit=$4
iface_speed=$5
current_pid=$$

bin_ps=`which ps`
bin_grep=`which grep`
bin_expr=`which expr`
bin_cat=`which cat`
bin_sort=`which sort`
bin_wc=`which wc`
bin_awk=`which awk`

# Check the interface exists
if [ ! -d /sys/class/net/$IF ] ; then echo "Interface $IF does not exist on this system. Possible interfaces: "`ls /sys/class/net/` ; exit 1 ; fi

# Temporary File Naming : Lets not overlap with a running script
                                                                                                                                                                        
tmpfile_rx=/tmp/check_bandwidth_"$IF"_rx.tmp.$current_pid
tmpfile_tx=/tmp/check_bandwidth_"$IF"_tx.tmp.$current_pid
reverse_tmpfile_rx=/tmp/check_bandwidth_"$IF"_reverse_rx.tmp.$current_pid
reverse_tmpfile_tx=/tmp/check_bandwidth_"$IF"_reverse_tx.tmp.$current_pid
deltafile_rx=/tmp/check_bandwidth_"$IF"_delta_rx.tmp.$current_pid
deltafile_tx=/tmp/check_bandwidth_"$IF"_delta_tx.tmp.$current_pid

warn_bits=`$bin_expr $warn '*' 1000000`
crit_bits=`$bin_expr $crit '*' 1000000`
iface_speed_bits=`$bin_expr $iface_speed '*' 1000000`

# Do the measurements
START_TIME=`date +%s`
n=0
while [ $n -lt $sec ]
    do
        cat /sys/class/net/$IF/statistics/rx_bytes >> $tmpfile_rx
        cat /sys/class/net/$IF/statistics/tx_bytes >> $tmpfile_tx
        sleep $INTERVAL
        let "n = $n + 1"
    done
FINISH_TIME=`date +%s`

$bin_cat $tmpfile_rx | $bin_sort -nr > $reverse_tmpfile_rx
$bin_cat $tmpfile_tx | $bin_sort -nr > $reverse_tmpfile_tx

while read line;
    do
        if [ -z "$RBYTES" ];
            then
                RBYTES=`cat /sys/class/net/$IF/statistics/rx_bytes`
                $bin_expr $RBYTES - $line >> $deltafile_rx;
            else
                $bin_expr $RBYTES - $line >> $deltafile_rx;
        fi
    RBYTES=$line
    done < $reverse_tmpfile_rx
while read line;
    do
        if [ -z "$TBYTES" ];
            then
                TBYTES=`cat /sys/class/net/$IF/statistics/tx_bytes`
                $bin_expr $TBYTES - $line >> $deltafile_tx;
            else
                $bin_expr $TBYTES - $line >> $deltafile_tx;
        fi
    TBYTES=$line
    done < $reverse_tmpfile_tx

while read line;
    do
        SUM_RBYTES=`$bin_expr $SUM_RBYTES + $line`
    done < $deltafile_rx
while read line;
    do
        SUM_TBYTES=`$bin_expr $SUM_TBYTES + $line`
    done < $deltafile_tx

let "DURATION = $FINISH_TIME - $START_TIME"
let "RBITS_SEC = ( $SUM_RBYTES * 8 ) / $DURATION"
let "TBITS_SEC = ( $SUM_TBYTES * 8 ) / $DURATION"

data_output_r_mbits=`echo "$RBITS_SEC 1000000" | $bin_awk '{ printf ("%.3f", $1/$2); }'`
data_output_t_mbits=`echo "$TBITS_SEC 1000000" | $bin_awk '{ printf ("%.3f", $1/$2); }'`
percent_output_r=`echo "$RBITS_SEC $iface_speed_bits 100" | $bin_awk '{ printf ("%.2f", $1/$2*$3); }'`
percent_output_t=`echo "$TBITS_SEC $iface_speed_bits 100" | $bin_awk '{ printf ("%.2f", $1/$2*$3); }'`
nagvis_perfdata_r="InUsage=$percent_output_r%"
nagvis_perfdata_t="OutUsage=$percent_output_t%"
pnp4nagios_perfdata_r="in=$RBITS_SEC;$warn_bits;$crit_bits"
pnp4nagios_perfdata_t="out=$TBITS_SEC;$warn_bits;$crit_bits"
pnp4nagios_perfdata_r_mbps="inBandwidth="$data_output_r_mbits"Mbps;$warn;$crit"
pnp4nagios_perfdata_t_mbps="outBandwidth="$data_output_t_mbits"Mbps;$warn;$crit"
nagiosSummaryText="IN $data_output_r_mbits Mbit/s OUT $data_output_t_mbits Mbit/s"
nagiosDetailText="$SUM_RBYTES/$SUM_TBYTES Bytes in $DURATION sec"
nagiosMetrics="$nagvis_perfdata_r $nagvis_perfdata_t $pnp4nagios_perfdata_r_mbps $pnp4nagios_perfdata_t_mbps"

# Decide if OK, Warning or Critical
if [ $RBITS_SEC -lt $warn_bits  -o  $TBITS_SEC -lt $warn_bits ]; then
        outputValue="OK"
        exitstatus=0
elif [ $RBITS_SEC -ge $warn_bits  -a  $RBITS_SEC -le $crit_bits ] || [ $TBITS_SEC -ge $warn_bits -a $TBITS_SEC -le $crit_bits ]; then
        outputValue="WARNING!" 
        exitstatus=1
elif [ $RBITS_SEC -gt $crit_bits  -o  $TBITS_SEC -gt $crit_bits ]; then
        outputValue="CRITICAL!" 
        exitstatus=2
else
    outputValue="unknown status"
    exitstatus=3
fi

#Cleanup tmp files
rm -f $tmpfile_rx
rm -f $tmpfile_tx
rm -f $reverse_tmpfile_rx
rm -f $reverse_tmpfile_tx
rm -f $deltafile_rx
rm -f $deltafile_tx

echo "$nagiosSummaryText - $outputValue - $nagiosDetailText | $nagiosMetrics" 
exit $exitstatus
