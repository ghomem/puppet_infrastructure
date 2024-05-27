class puppet_infrastructure::sysmon_puppet_cert_status {

  $check_puppet_cert_health_deps = [ 'python3-yaml' ]
  package { $check_puppet_cert_health_deps:
    ensure => present,
    require => Exec['apt_update'],
  }

  $localdir = lookup('filesystem::localdir')
  $file_name = "${localdir}/bin/check_puppet_cert_health.py"

  file { "$file_name":
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    source  => 'puppet:///modules/puppet_infrastructure/sysmon/check_puppet_cert_health.py',
    require => [ File[ "${localdir}/bin" ], Package[$check_puppet_cert_health_deps] ],
  }

  # along with permission for launching puppet cert health check runs
  sudo::conf { 'check_puppet_cert_health':
    priority => 20,
    content  => "naemon ALL=NOPASSWD:${localdir}/bin/check_puppet_cert_health.py",
  }

}
