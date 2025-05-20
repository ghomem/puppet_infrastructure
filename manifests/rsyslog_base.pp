class puppet_infrastructure::rsyslog_base {

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
}
