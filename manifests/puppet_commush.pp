### Purpose ########
# This class provides helpers for pushing node declarations
# from the deployment user directories
class puppet_infrastructure::puppet_commush {

  $localdir = lookup('filesystem::localdir')

  file { "${localdir}/bin/commush.sh":
  mode    => '0755',
  owner   => 'root',
  group   => 'root',
  source  => 'puppet:///modules/puppet_infrastructure/puppet/commush.sh',
  require => File[ "${localdir}/bin" ],
  }

}
