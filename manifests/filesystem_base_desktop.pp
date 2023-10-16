### Purpose ########
# This class provides basic filesystem definitions for all desktop machines
class puppet_infrastructure::filesystem_base_desktop (
  # Notice rsyslog may set different permissions when creating the syslog file
  # but then they will be changed by puppet
  Boolean $customize_syslog_mode = false,
  String $syslog_mode            = 'u=rw,g=r,o=',
) {

  $localdir = lookup('filesystem::localdir')
  $bindir   = lookup('filesystem::bindir')
  $etcdir   = lookup('filesystem::etcdir')

  $basedirs = [ $localdir, $bindir, $etcdir ]

  # local dir for custom scripts
  file { [ $basedirs ]:
  ensure => directory,
  owner  => root,
  group  => root,
  mode   => '0644'
  }

  # Here we assume we are on an ubuntu node as that's what we use for desktops
  # (you'll need to refactor this if you want to use it in other distributions,
  # see filesystem_base.pp for an example)
  $syslog_filepath = '/var/log/syslog'
  $syslog_owner    = 'syslog'
  $syslog_group    = 'adm'
  if ($customize_syslog_mode) {
    file { $syslog_filepath:
      ensure => 'present',
      owner  => $syslog_owner,
      group  => $syslog_group,
      mode   => $syslog_mode,
    }
  }
}
