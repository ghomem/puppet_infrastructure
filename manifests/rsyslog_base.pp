# Shared rsyslog setup for both server and client nodes.
# Installs rsyslog + GnuTLS and copies Puppet TLS material so rsyslog can use it.

class puppet_infrastructure::rsyslog_base (
  Optional[String] $ssldir_override = undef,
) {

  # Install rsyslog and TLS support.

  package { ['rsyslog', 'rsyslog-gnutls']:
    ensure => installed,
  }

  # Keep the legacy syslog user/group layout on RedHat-based systems.

  if $facts['os']['family'] == 'RedHat' {
    group { 'syslog':
      ensure    => present,
      gid       => 0,
      allowdupe => true,
    }

    user { 'syslog':
      ensure    => present,
      uid       => 0,
      allowdupe => true,
    }
  }

  # Normal nodes use the default Puppet SSL dir; the master can override it.

  $ssldir = $ssldir_override ? {
    undef   => '/var/lib/puppet/ssl',
    default => $ssldir_override,
  }

  $certname = $trusted['certname']

  # Copy the CA, cert and key to a place rsyslog can read.

  file { '/etc/rsyslog.d/tls':
    ensure  => directory,
    owner   => 'syslog',
    group   => 'syslog',
    mode    => '0755',
    require => Package['rsyslog'],
  }

  file { '/etc/rsyslog.d/tls/ca.pem':
    source  => "${ssldir}/certs/ca.pem",
    owner   => 'syslog',
    group   => 'syslog',
    mode    => '0644',
    require => File['/etc/rsyslog.d/tls'],
  }

  file { "/etc/rsyslog.d/tls/${certname}.pem":
    source  => "${ssldir}/certs/${certname}.pem",
    owner   => 'syslog',
    group   => 'syslog',
    mode    => '0644',
    require => File['/etc/rsyslog.d/tls'],
  }

  file { "/etc/rsyslog.d/tls/${certname}.key":
    source  => "${ssldir}/private_keys/${certname}.pem",
    owner   => 'syslog',
    group   => 'syslog',
    mode    => '0600',
    require => File['/etc/rsyslog.d/tls'],
  }

  # Keep rsyslog running and reload it whenever the TLS files change.

  service { 'rsyslog':
    ensure    => running,
    enable    => true,
    provider  => 'systemd',
    subscribe => File['/etc/rsyslog.d/tls'],
  }
}
