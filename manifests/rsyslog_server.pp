# Configure a node as the central rsyslog listener.
# Receives local and remote logs over TLS, stores them under a host-based tree,
# and manages rotation and retention for those files.

class puppet_infrastructure::rsyslog_server (
  Integer $port                       = 6514,
  String  $log_root                   = '/var/log',
  Integer $active_days                = 7,
  Integer $retention_days             = 7,
  Integer $max_sessions               = 2000,
  Boolean $notify_on_connection_close = false,
) {

  # Reuse the shared rsyslog setup for package install, TLS material and service management.
  include puppet_infrastructure::rsyslog_base

  $certname = $trusted['certname']

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

  # Rotate active per-host log files after the configured active period.
  file { '/etc/logrotate.d/rsyslog-hosts':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('puppet_infrastructure/rsyslog/rsyslog-hosts.logrotate.epp', {
      log_root    => $log_root,
      active_days => $active_days,
    }),
  }

  # Remove compressed rotated logs after the configured retention period.
  cron { 'rsyslog_hosts_retention_cleanup':
    command => "/usr/bin/find ${log_root}/hosts -type f -name '*.gz' -mtime +${retention_days} -delete",
    user    => 'root',
    hour    => '3',
    minute  => '17',
  }

}
