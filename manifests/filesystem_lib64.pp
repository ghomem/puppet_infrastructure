### Purpose ########
# This class provides a ubuntu only filesystem compatibility measure related to nagios plugins invocation
class puppet_infrastructure::filesystem_lib64 {

  file { '/usr/lib64/':
    ensure => 'directory',
    owner  => 'root',
    group  => 'root',
  }

  file { '/usr/lib64/nagios/':
    ensure  => 'link',
    target  => '/usr/lib/nagios',
    require => File['/usr/lib64/']
  }

}
