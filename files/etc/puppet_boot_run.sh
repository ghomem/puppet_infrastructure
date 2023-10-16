#!/bin/bash

"Puppet run executed during boot at: `date`" > /tmp/puppet_boot_run.log
/opt/puppetlabs/bin/puppet agent -t
exit 0
