### Purpose ########
# This class provides a nagios plugin that can be used trigger and monitor puppet runs, cpu, memory and zimbra
class puppet_infrastructure::sysmon_base {

  $os_family = $facts['os']['family']
    
  case $os_family {
    'Debian': {
      $packagename = monitoring-plugins-standard
    }
    'RedHat': {
      $packagename = nagios-plugins-disk
    }
    default: {
    }
  }

  $localdir = lookup('filesystem::localdir')
  $bindir   = lookup('filesystem::bindir')


# puppet
  file { "${localdir}/bin/nagios-puppet.sh":
  mode    => '0755',
  owner   => 'root',
  group   => 'root',
  source  => 'puppet:///modules/puppet_infrastructure/sysmon/nagios-puppet.sh',
  require => File[ "${localdir}/bin" ],
  }

# reboot check
  file { "${localdir}/bin/check_reboot_required.sh":
  mode    => '0755',
  owner   => 'root',
  group   => 'root',
  source  => 'puppet:///modules/puppet_infrastructure/sysmon/check_reboot_required.sh',
  require => File[ "${localdir}/bin" ],
  }

# file handles check
  file { "${localdir}/bin/check_file_handles.sh":
  mode    => '0755',
  owner   => 'root',
  group   => 'root',
  source  => 'puppet:///modules/puppet_infrastructure/sysmon/check_file_handles.sh',
  require => File[ "${localdir}/bin" ],
  }

# netstat conns check
  file { "${localdir}/bin/check_netstat_conns.sh":
  mode    => '0755',
  owner   => 'root',
  group   => 'root',
  source  => 'puppet:///modules/puppet_infrastructure/sysmon/check_netstat_conns.sh',
  require => File[ "${localdir}/bin" ],
  }

# netstat connections, IPs, port check
  file { "${localdir}/bin/check_netstat_cip.sh":
  mode    => '0755',
  owner   => 'root',
  group   => 'root',
  source  => 'puppet:///modules/puppet_infrastructure/sysmon/check_netstat_cip.sh',
  require => File[ "${localdir}/bin" ],
  }

# package count
  file { "${localdir}/bin/check_package_count.sh":
  mode    => '0755',
  owner   => 'root',
  group   => 'root',
  source  => 'puppet:///modules/puppet_infrastructure/sysmon/check_package_count.sh',
  require => File[ "${localdir}/bin" ],
  }

# bandwidth
  file { "${localdir}/bin/check_bandwidth.sh":
  mode    => '0755',
  owner   => 'root',
  group   => 'root',
  source  => 'puppet:///modules/puppet_infrastructure/sysmon/check_bandwidth.sh',
  require => File[ "${localdir}/bin" ],
  }

# disk latency
  file { "${localdir}/bin/check_dd_latency.sh":
  mode    => '0755',
  owner   => 'root',
  group   => 'root',
  source  => 'puppet:///modules/puppet_infrastructure/sysmon/check_dd_latency.sh',
  require => File[ "${localdir}/bin" ],
  }

# cpu
  file { '/usr/lib64/nagios/plugins/check_cpu.py':
  mode    => '0755',
  owner   => 'root',
  group   => 'root',
  content => template('puppet_infrastructure/sysmon/check_cpu.py.erb'),
  require => Class['puppet_infrastructure::packages_base'],
  }

# memory
  file { '/usr/lib64/nagios/plugins/check_mem.pl':
  mode    => '0755',
  owner   => 'root',
  group   => 'root',
  source  => 'puppet:///modules/puppet_infrastructure/sysmon/check_mem.pl',
  require => Class['puppet_infrastructure::packages_base'],
  }

# operating system version
  file { "${localdir}/bin/check_os_version.sh":
  mode    => '0755',
  owner   => 'root',
  group   => 'root',
  source  => 'puppet:///modules/puppet_infrastructure/sysmon/check_os_version.sh',
  require => File[ "${localdir}/bin" ],
  }

# ssl certificate expiration
  file { "${localdir}/bin/check_http_ssl_cert.sh":
  mode    => '0755',
  owner   => 'root',
  group   => 'root',
  source  => 'puppet:///modules/puppet_infrastructure/sysmon/check_http_ssl_cert.sh',
  require => File[ "${localdir}/bin" ],
  }

  file { "${localdir}/bin/elastic_query_check.py":
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    source  => 'puppet:///modules/puppet_infrastructure/sysmon/elastic_query_check.py',
    require => File[ "${localdir}/bin" ],
  }

}
