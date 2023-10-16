### Purpose ########
# This class provides a nagios plugin that can be used trigger and monitor MYSQL db test restores
define puppet_infrastructure::sysmon_mysqldump_health ( $mysqluser, $mysqlpassword, $dirs) {

  $bindir   = lookup('filesystem::bindir')
  $script_prefix = 'check-mysqldump-health'
  $scriptname = "${script_prefix}.sh"

  file { "${bindir}/${scriptname}":
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => template("puppet_infrastructure/sysmon/${script_prefix}.sh.erb"),
    require => File[ $bindir ],
  }

}

