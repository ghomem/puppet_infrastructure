### Purpose ########
# This class provides scripts for systems with Cloudmin

class puppet_infrastructure::cloudmin_scripts {
  $localdir = lookup('filesystem::localdir')

  file { "${localdir}/bin/cloudmin-export.sh":
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    source  => 'puppet:///modules/puppet_infrastructure/cloudmin/cloudmin-export.sh',
    require => File[ "${localdir}/bin" ],
  }

  file { "${localdir}/bin/cloudmin-import.sh":
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    source  => 'puppet:///modules/puppet_infrastructure/cloudmin/cloudmin-import.sh',
    require => File[ "${localdir}/bin" ],
  }
}
