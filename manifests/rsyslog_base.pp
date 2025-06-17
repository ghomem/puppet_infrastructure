# frozen_string_literal: true
# Install rsyslog with TLS support, create /etc/rsyslog/tls
class puppet_infrastructure::rsyslog_base {

  # 1. Packages
  package { ['rsyslog', 'rsyslog-gnutls']:
    ensure => installed,
  }

  # 2. Legacy “syslog” account for EL
  if $facts['os']['family'] == 'RedHat' {
    group { 'syslog': ensure => present, gid => 0, allowdupe => true }
    user  { 'syslog': ensure => present, uid => 0, allowdupe => true }
  }

  # 3. Copy Puppet certificates so rsyslog can read them
  $ssldir   = $settings::ssldir
  $certname = $trusted['certname']

  file { '/etc/rsyslog/tls':
    ensure => directory,
    owner  => 'syslog',
    group  => 'syslog',
    mode   => '0755',
    require => Package['rsyslog'],
  }

  file { '/etc/rsyslog/tls/ca.pem':
    source => "${ssldir}/certs/ca.pem",
    owner  => 'syslog', group => 'syslog', mode => '0644',
    require => File['/etc/rsyslog/tls']
  }

  file { "/etc/rsyslog/tls/${certname}.pem":
    source => "${ssldir}/certs/${certname}.pem",
    owner  => 'syslog', group => 'syslog', mode => '0644',
    require => File['/etc/rsyslog/tls']
  }

  file { "/etc/rsyslog/tls/${certname}.key":
    source => "${ssldir}/private_keys/${certname}.pem",
    owner  => 'syslog', group => 'syslog', mode => '0600',
    require => File['/etc/rsyslog/tls']
  }

  # 4. Service
  service { 'rsyslog':
    ensure     => running,
    enable     => true,
    provider   => 'systemd',
    subscribe  => File['/etc/rsyslog/tls'],
  }
}
