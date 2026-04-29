# Adds an AppArmor local exception for rsyslog to write to a custom log path.
class puppet_infrastructure::rsyslog_apparmor_exception (
  Stdlib::Absolutepath $logs_dir,
) {

  file { '/etc/apparmor.d/local/usr.sbin.rsyslogd':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "${logs_dir}/ rw,\n${logs_dir}/** rwk,\n",
    notify  => Exec['reload_rsyslog_apparmor'],
  }

  exec { 'reload_rsyslog_apparmor':
    command     => '/sbin/apparmor_parser -r /etc/apparmor.d/usr.sbin.rsyslogd',
    refreshonly => true,
    path        => ['/sbin', '/usr/sbin', '/bin', '/usr/bin'],
    notify      => Service['rsyslog'],
  }

}
