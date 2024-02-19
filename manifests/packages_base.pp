### Purpose ########
# This class provides the minimum set of packages for a generic Ubuntu node
class puppet_infrastructure::packages_base (
  Boolean $unattended_upgrades = false,
) {
  
  #determine if the system is Ubuntu or RedHat
  $os_family = $facts['os']['family']


  # this line is needed to make sure apt-get update or dnf-makecache runs on each puppet run
  if $os_family == 'RedHat' {
    exec { 'dnf-makecache':
      command     => 'dnf makecache',
      path        => ['/bin', '/usr/bin', '/sbin', '/usr/sbin'],
      refreshonly => false
    }
  } else {
    class { 'apt': update => { frequency => 'always' } }
  }

  # This wiill be ran for Ubuntu and RHEL8 and 9, and the packages are different
  # Determine the package manager and package names based on the OS
  if $os_family == 'Debian' {
    $package_manager = 'apt'
    $nagios_package_name = 'monitoring-plugins-standard'
    $package_list = ['iptables-persistent', $nagios_package_name, 'ecryptfs-utils', 'vim', 'wget', 'aptitude', 'acl']
  } elsif $os_family == 'RedHat' {
    include puppet_infrastructure::extra_packages_el
    $package_manager = 'dnf'
    $nagios_package_name = 'nagios-plugins-all'
    $package_list = ['iptables-services', $nagios_package_name, 'vim', 'wget', 'yum-utils', 'acl']
  }

  # Define a custom exec resource to update the package lists
  exec { 'update-package-lists':
    command     => "${package_manager} update -y",
    path        => ['/bin', '/usr/bin', '/sbin', '/usr/sbin'],
    refreshonly => true
  }

  # Package resource declaration
  package { $package_list:
    ensure  => present,
    require => Exec['update-package-lists'],
  }

  # Notify the 'update-package-lists' exec to run before installing packages
  Exec['update-package-lists'] ~> Package[$package_list]

  package { [ 'supervisor' , 'cloud-init' ]: ensure => absent, }

  if $unattended_upgrades {
    if $os_family == 'Debian' {
      package { 'unattended-upgrades': ensure => installed, }
    } elsif $os_family == 'RedHat' {
      package { 'dnf-automatic': ensure => installed, }
    }
  } else {
    if $os_family == 'Debian' {
      package { 'unattended-upgrades': ensure => absent, }
    } elsif $os_family == 'RedHat' {
      package { 'dnf-automatic': ensure => absent, }
    }
  }
}

