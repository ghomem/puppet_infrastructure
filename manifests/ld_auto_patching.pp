### Purpose ########
# This class provides:
# - a program to automatically apply the LD patches available in $ldpatchesdir
# - a systemd service and timer to run the program above periodically

class puppet_infrastructure::ld_auto_patching {
  $localdir = lookup('filesystem::localdir')
  $localbindir = lookup('filesystem::bindir')
  $ldpatchesdir = "${localdir}/ld_patches"
  # directory to put *.tar.gz files with LD patches
  file { $ldpatchesdir:
    ensure => 'directory',
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }
  # script to apply patches
  file { "${localbindir}/ld-apply-patches":
    ensure  => present,
    content => template('puppet_infrastructure/ld_auto_patching/ld-apply-patches.erb'),
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    require => File[ $ldpatchesdir ],
  }
  # add systemd service
  file { '/etc/systemd/system/ld-apply-patches.service':
    ensure  => present,
    content => template('puppet_infrastructure/ld_auto_patching/ld-apply-patches.service.erb'),
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    require => File[ "${localbindir}/ld-apply-patches" ],
  }
  # add systemd timer
  include puppet_infrastructure::systemd_daemon_reload
  file { '/etc/systemd/system/ld-apply-patches.timer':
    ensure  => present,
    source  => 'puppet:///modules/puppet_infrastructure/ld_auto_patching/ld-apply-patches.timer',
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    require => File[ "/etc/systemd/system/ld-apply-patches.service" ],
    notify  => [
      Service[ 'ld-apply-patches.timer' ],
      Class[ 'puppet_infrastructure::systemd_daemon_reload' ], # This should be removed for Puppet >= 6.1
    ],
  }
  # enable systemd timer
  service { 'ld-apply-patches.timer':
    provider => 'systemd',
    enable   => true,
    ensure   => running,
    require  => File[ '/etc/systemd/system/ld-apply-patches.timer' ],
  }
}
