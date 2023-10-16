#!/bin/bash
# This wrapper only calls check_http and shortens the output to be readable in Nagios overview panel
/usr/lib64/nagios/plugins/check_http "$@" | sed "s/Certificate //g" | sed "s/will expire/expires/g"
exit ${PIPESTATUS[0]}
