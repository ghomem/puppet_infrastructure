# Configure a node as the central rsyslog listener.
# Receives local and remote logs over TLS, stores them under a host-based tree,
# and manages rotation and retention for those files.

class puppet_infrastructure::rsyslog_server (
  Integer $port                       = 6514,
  String  $log_root                   = '/var/log',
  Integer $active_days                = 7,
  Integer $retention_days             = 7,
  Integer[0, 23] $rotation_hour       = 0,
  Integer[0, 59] $rotation_minute     = 0,
  Integer[0, 23] $retention_hour      = 3,
  Integer[0, 59] $retention_minute    = 17,
  Integer $max_sessions               = 2000,
  Boolean $notify_on_connection_close = false,
) {

  # Reuse the shared rsyslog setup for package install, TLS material and service management.
  include puppet_infrastructure::rsyslog_base

  $certname = $trusted['certname']
  $bindir   = lookup('filesystem::bindir')

  # Render the TLS listener config and restart rsyslog if it changes.
  file { '/etc/rsyslog.d/30-listener.conf':
    content => epp('puppet_infrastructure/rsyslog/listener_simple.conf.epp', {
      port                       => $port,
      certname                   => $certname,
      log_root                   => $log_root,
      max_sessions               => $max_sessions,
      notify_on_connection_close => $notify_on_connection_close,
    }),
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    notify => Service['rsyslog'],
  }

  # self-forwarding removed on purpose to avoid recursive logging loops
  # Ensure any old self-forward config is removed to avoid recursive logging loops.
  file { '/etc/rsyslog.d/40-forward-self.conf':
    ensure => absent,
    notify => Service['rsyslog'],
  }

  # Run the system logrotate timer at the configured time.
  file { '/etc/systemd/system/logrotate.timer.d':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { '/etc/systemd/system/logrotate.timer.d/override.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('puppet_infrastructure/rsyslog/logrotate.timer.override.epp', {
      rotation_hour   => $rotation_hour,
      rotation_minute => $rotation_minute,
    }),
    require => File['/etc/systemd/system/logrotate.timer.d'],
    notify  => Exec['reload systemd for logrotate timer'],
  }

  exec { 'reload systemd for logrotate timer':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
    notify      => Exec['restart logrotate timer'],
  }

  exec { 'restart logrotate timer':
    command     => '/bin/systemctl restart logrotate.timer',
    refreshonly => true,
  }

  # Rotate active per-host log files daily; clear-text retention is handled separately.
  file { '/etc/logrotate.d/rsyslog-hosts':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('puppet_infrastructure/rsyslog/rsyslog-hosts.logrotate.epp', {
      log_root => $log_root,
    }),
  }

  # Compress rotated clear-text logs after the active period and remove
  # compressed logs after the configured retention period.
  file { "${bindir}/rsyslog-hosts-retention.sh":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => epp('puppet_infrastructure/rsyslog/rsyslog-hosts-retention.sh.epp', {
      log_root       => $log_root,
      active_days    => $active_days,
      retention_days => $retention_days,
    }),
  }

  cron { 'rsyslog_hosts_retention_cleanup':
    command => "${bindir}/rsyslog-hosts-retention.sh",
    user    => 'root',
    hour    => $retention_hour,
    minute  => $retention_minute,
    require => File["${bindir}/rsyslog-hosts-retention.sh"],
  }

}
