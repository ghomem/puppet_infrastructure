class puppet_infrastructure::rsyslog_base {

  $certname = $trusted['certname']
  $pkgs = ['rsyslog', 'rsyslog-gnutls']

  package { $pkgs: ensure => installed }

  if $facts['os']['family'] == 'RedHat' {
    group { 'syslog': ensure => present, gid => 0, allowdupe => true }
    user  { 'syslog': ensure => present, uid => 0, allowdupe => true }
  }

  # --- Service (systemd everywhere we care about) ---------------------
  service { 'rsyslog':
    ensure     => running,
    enable     => true,
    provider   => 'systemd',
    hasstatus  => true,
    hasrestart => true,
    subscribe  => Package[$pkgs],
  }

  $ssldir   = "/var/lib/puppet/ssl"

  file { '/etc/rsyslog.d/tls':
    ensure => directory,
    owner  => 'syslog',
    group  => 'syslog',
    mode   => '0755',
  }

  file { '/etc/rsyslog.d/tls/ca.pem':
    source => "${ssldir}/certs/ca.pem",
    owner  => 'syslog',
    group  => 'syslog',
    mode   => '0644',
  }

  file { "/etc/rsyslog.d/tls/${certname}.crt":
    source => "${ssldir}/certs/${certname}.pem",
    owner  => 'syslog',
    group  => 'syslog',
    mode   => '0644',
  }

  file { "/etc/rsyslog.d/tls/${certname}.key":
    source => "${ssldir}/private_keys/${certname}.pem",
    owner  => 'syslog',
    group  => 'syslog',
    mode   => '0600',
  }

}
