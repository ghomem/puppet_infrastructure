### Purpose ########
# This class implements a simple multi host remote to local daily synchronization
define puppet_infrastructure::sync ( $localdir, $remotedir, $localuser, $remoteuser, $hour, $minute, $hostlist, $suffix = '', Integer[0] $bwlimit_mbitps = 0, )  {

  $bindir  = lookup('filesystem::bindir')
  $mytag   = $title

  # determine the option string for --bwlimit
  case $bwlimit_mbitps {
    # if we are at zero (0) which is our default we do not write anything in this option's string
    0: {
      $bwlimit_opt = ''
    }
    default:  {
      # notice that in puppet "If you divide two integers, the result will not be a float"
      # so we start by getting a float
      $bwlimit_mbitps_float = Float($bwlimit_mbitps)
      # we convert megabit (i.e. 1000*1000 bit) to megabytes (i.e. 1024*10254 bytes)
      $bwlimit_mbyteps_float = $bwlimit_mbitps_float*1000.0*1000.0/(8.0*1024.0*1024.0)
      # let's show two decimal plates
      $bwlimit_mbyteps_str = sprintf('%.2f', $bwlimit_mbyteps_float)
      # the m here means mega bytes (see rsync manpage)
      # notice the leading whitespace
      $bwlimit_opt = " --bwlimit=${bwlimit_mbyteps_str}m"
    }
  }

  # parameters are needed for resources and erb template

  # we use a tag for this sync, in case we need multiple instances

  file { "${bindir}/sync-${mytag}.sh":
  mode    => '0755',
  owner   => 'root',
  group   => 'root',
  content => template('puppet_infrastructure/backup/sync.sh.erb'),
  }

  cron { "cron_sync_${mytag}":
  command => "${bindir}/sync-${mytag}.sh",
  user    => $localuser,
  hour    => $hour,
  minute  => $minute,
  require => File[ "${bindir}/sync-${mytag}.sh" ]
  }

}
