### Purpose ########
# This class provides helper scripts for yum based system updates

class puppet_infrastructure::filesystem_yum {

  $localdir = lookup('filesystem::localdir')

  # security surface updates
  file { "${localdir}/bin/yum-update-surface.sh":
  mode    => '0755',
  owner   => 'root',
  group   => 'root',
  source  => 'puppet:///modules/puppet_infrastructure/yum/yum-update-surface.sh',
  require => File[ "${localdir}/bin" ],
  }

  # full updates
  file { "${localdir}/bin/yum-update-dist.sh":
  mode    => '0755',
  owner   => 'root',
  group   => 'root',
  source  => 'puppet:///modules/puppet_infrastructure/yum/yum-update-dist.sh',
  require => File[ "${localdir}/bin" ],
  }

}
