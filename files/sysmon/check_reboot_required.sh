#!/bin/bash
# Based on /usr/lib/update-notifier/update-motd-reboot-required

STATE="OK - No reboot required"
status=0

if [ -f /var/run/reboot-required ]; then
  STATE="WARNING - Reboot required to update host (/var/run/reboot-required found)"
  status=1
fi

echo "$STATE"
exit $status
