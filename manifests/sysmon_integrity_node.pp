### Purpose ########
# This class provides a nagios plugin that can be used trigger and monitor integrity checks
class puppet_infrastructure::sysmon_integrity_node ( $checklist = '' ) {

  $bindir   = lookup('filesystem::bindir')

  # integrity, template uses the checklist variable
  file { "${bindir}/nagios-integrity.sh":
  mode    => '0755',
  owner   => 'root',
  group   => 'root',
  content => template('puppet_infrastructure/sysmon/nagios-integrity.sh.erb'),
  require => File[ $bindir ],
  }

}
