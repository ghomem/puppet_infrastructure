### Purpose ########
# This class implements simple tar based generic backups
define puppet_infrastructure::backup (
  $basedir, $prefix, $backdir, $ndays, $bindir,
  $user = 'root',
  $hour = '23',
  $minute = '0',
  $monthday = '*',
  Boolean $compression = true,
) {

  # parameters are needed for resources and erb template

  file { "${bindir}/backup-${title}.sh":
  mode    => '0755',
  owner   => 'root',
  group   => 'root',
  content => template('puppet_infrastructure/backup/backup.sh.erb'),
  }

  cron { "cron_${title}_backup":
  command   => "${bindir}/backup-${title}.sh",
  user      => $user,
  hour      => $hour,
  minute    => $minute,
  monthday  => $monthday,
  require   => File[ "${bindir}/backup-${title}.sh" ]
  }

}
