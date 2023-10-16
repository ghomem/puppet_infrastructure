#!/bin/bash

# check that we receive the PORT as an argument
if [ "$1" == "" ];then
echo "Check unique IPs on PORT and ratio of nr of connections to PORT per unique IP on PORT"
echo
echo "Usage: $0 PORT [IP_WARN] [IP_CRIT] [CPI_WARN] [CPI_CRIT]"
echo
echo "Example: $0 443 :  Check TCP connections"
exit 3
fi

# default exit values
STATE="OK"
status=0

# build PORT string, ie, :443
PORT=":""$1"

# number of connections
NUM_OF_CONNS="$(netstat -antu | awk -v arg="$PORT" '$4 ~ arg' | grep -v LISTEN | awk '{print $5}' | cut -d: -f1 | grep -v 127.0.0.1 | wc -l)"

# number of unique IPs
NUM_OF_IPS="$(netstat -antu | awk -v arg="$PORT" '$4 ~ arg' | grep -v LISTEN | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn | grep -v 127.0.0.1 | wc -l)"

# if we have 0 in NUM_OF_IPS, we don't want to divide by zero
if [ "$NUM_OF_IPS" == "0" ];then
  RATIO="0"
else
  # number of connections divided by the number of unique IPs
  RATIO="$(python3 -c "print ($NUM_OF_CONNS / $NUM_OF_IPS)")"
fi

# empty strings don't affect the values of $2, $3, $4, $5
echo "$STATE - $status exit status | num_of_ips=$NUM_OF_IPS;$2;$3; conn_per_ip=$RATIO;$4;$5;"

exit $status
