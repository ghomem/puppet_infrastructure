# For Puppet < 6.1 the systemd provider doesn't scan for changed units, see:
# https://tickets.puppetlabs.com/browse/PUP-3483
#
# Therefore for updated services that need a 'systemctl daemon-reload', we need
# to apply this technique:
# https://www.grahamedgecombe.com/blog/2018/03/09/systemctl-daemon-reload-and-puppet

class puppet_infrastructure::systemd_daemon_reload {

  exec { '/bin/systemctl daemon-reload':
    refreshonly => true,
  }

}
