### Purpose ########
# This class provides a ubuntu only filesystem compatibility measure related to nagios plugins invocation
class puppet_infrastructure::filesystem_lib64 {

  # in Kubuntu 20.04 the folder /usr/lib64 already exists
  # and has content in it, since we use the same paths for sysmon
  # the best way is to create the specific link for the nagios folder
  # when dealing with a 20.04 machine
  $major_release = $facts['os']['release']['major']

  if $major_release == '16.04' or $major_release == '18.04' {

    file { '/usr/lib64/':
      ensure => 'link',
      target => '/usr/lib',
    }

  } else {

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

}
