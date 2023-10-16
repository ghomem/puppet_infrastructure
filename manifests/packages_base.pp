### Purpose ########
# This class provides the minimum set of packages for a generic Ubuntu node
class puppet_infrastructure::packages_base (
  Boolean $unattended_upgrades = false,
) {

  # this line is needed to make sure apt-get update runs on each puppet run
  class { 'apt': update => { frequency => 'always' } }
  
  $major_release = $facts['os']['release']['major']
  
  # we only support LTS versions and there has been
  # a package name change from 18.04 to 20.04, hence this verification
  if $major_release == '16.04' or $major_release == '18.04' {
    $nagios_plugins_packagename = nagios-plugins-basic
  }
  else {
    $nagios_plugins_packagename = monitoring-plugins-standard
  }

  # each package resource needs its owns require of apt_update to ensure it runs BEFORE apt-get install
  package { [ 'iptables-persistent', $nagios_plugins_packagename, 'ecryptfs-utils', 'vim', 'wget', 'aptitude', 'acl' ]: ensure => present, require => Exec['apt_update'] }

  package { [ 'supervisor' , 'cloud-init' ]: ensure => absent, }

  if $unattended_upgrades {
    package { 'unattended-upgrades': ensure => installed, }
  } else {
    package { 'unattended-upgrades': ensure => absent, }
  }

}

