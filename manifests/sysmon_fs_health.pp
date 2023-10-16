### Purpose ########
# This class provides a nagios plugin that can be used trigger and monitor puppet runs, cpu, memory and zimbra
define puppet_infrastructure::sysmon_fs_health ( $basedir, $size_threshold, $nfiles ) {

  $bindir   = lookup('filesystem::bindir')
  $volname = $title # name of the volume to be checked
  $prefix = 'check-fs-health'
  $scriptname = "${prefix}-${volname}.sh"

  sudo::conf { "nagios_fs_health_${volname}": priority => 10, content  => "nagios ALL=NOPASSWD:${bindir}/${scriptname}" }

  file { "${bindir}/${scriptname}":
  mode    => '0755',
  owner   => 'root',
  group   => 'root',
  content => template("puppet_infrastructure/sysmon/${prefix}.sh.erb"),
  require => File[ $bindir ],
  }

}
