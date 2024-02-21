### Purpose ########
# This class provides basic filesystem definitions for all non-desktop machines
class puppet_infrastructure::filesystem_base (
  # Notice rsyslog may set different permissions when creating the syslog file
  # but then they will be changed by puppet
  Boolean $customize_syslog_mode = false,
  String $syslog_mode            = 'u=rw,g=r,o=',
){

  $localdir = lookup('filesystem::localdir')
  $bindir   = lookup('filesystem::bindir')
  $etcdir   = lookup('filesystem::etcdir')
  $backdir  = lookup('filesystem::backdir')
  $pkgsdir  = lookup('filesystem::pkgsdir')

  $basedirs = [ $localdir, $bindir, $etcdir, $backdir, $pkgsdir ]

  # local dir for custom scripts
  file { [ $basedirs ]:
  ensure => directory,
  owner  => root,
  group  => root,
  mode   => '0644'
  }

  # fix locale errors with ssh sessions
  file { '/etc/default/locale':
  source => 'puppet:///modules/puppet_infrastructure/locale/locale',
  owner  => root,
  group  => root,
  mode   => '0644'
  }

  case $facts['os']['family'] {
    # on CentOS and similar RedHat systems we want mypython to link to python3 on '/usr/bin/python3'
    'RedHat': {
      $mypython_target = '/usr/bin/python3'
      $syslog_filepath = '/var/log/messages'
      $syslog_owner    = 'root'
      $syslog_group    = 'root'
    }
    default:  {
      $mypython_target = '/usr/bin/python3'
      $syslog_filepath = '/var/log/syslog'
      $syslog_owner    = 'syslog'
      $syslog_group    = 'adm'
    }
  }

  file {"${bindir}/mypython":
    ensure => link,
    target => $mypython_target,
    mode   => 'u=rwx,g=rx,o=rw',
  }

  if ($customize_syslog_mode) {
    file { $syslog_filepath:
      ensure => 'present',
      owner  => $syslog_owner,
      group  => $syslog_group,
      mode   => $syslog_mode,
    }
  }

}
