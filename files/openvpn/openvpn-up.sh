#!/bin/sh

BR=$1
ETHDEV=$2
TAPDEV=$3

ip link set "$TAPDEV" up
ip link set "$ETHDEV" promisc on
brctl addif $BR $TAPDEV
