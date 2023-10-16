# Purpose:
#   Stream logfiles to centralized log service
# Inputs:
#   An hash of hashes with (syslog) tags and the corresponding log files
class puppet_infrastructure::logfiles (
  $logs_to_stream,
) {

  # rsyslog config file
  file { '/etc/rsyslog.d/35-logfiles-stream.conf':
    ensure  => 'file',
    notify  => Service['rsyslog'],
    mode    => '0664',
    owner   => 'root',
    group   => 'root',
    content => template('puppet_infrastructure/logfiles/35-logfiles-stream.conf.erb'),
  }

  # We need a second rsyslog config file to avoid logging to /var/log/syslog.
  # This needs to be named so it's after the config file that send to the centralized log service
  # but before the default rsyslog config file (50-default.conf).
  file { '/etc/rsyslog.d/45-logfiles-stop.conf':
    ensure  => 'file',
    notify  => Service['rsyslog'],
    mode    => '0664',
    owner   => 'root',
    group   => 'root',
    content => template('puppet_infrastructure/logfiles/45-logfiles-stop.erb'),
  }

}
