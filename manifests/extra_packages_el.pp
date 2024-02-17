class puppet_infrastructure::extra_packages_el {

  $os_major_version = $facts['os']['release']['major']
  $os_architecture = $facts['os']['architecture']

  # Install the EPEL release package for RHEL 8 or 9
  exec { 'install-epel-release':
    command => "sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-${os_major_version}.noarch.rpm",
    unless  => 'rpm -q epel-release',
    path    => ['/bin', '/usr/bin', '/sbin', '/usr/sbin'],
  }

  # Enable the CodeReady Builder repository for RHEL 8 or 9
  exec { 'enable-codeready-builder-repo':
    command => "sudo subscription-manager repos --enable \"codeready-builder-for-rhel-${os_major_version}-${os_architecture}-rpms\"",
    unless  => "subscription-manager repos --list-enabled | grep -q 'codeready-builder-for-rhel-${os_major_version}-${os_architecture}-rpms'",
    path    => ['/bin', '/usr/bin', '/sbin', '/usr/sbin'],
    require => Exec['install-epel-release'],  # Ensure EPEL is installed first
  }

}
