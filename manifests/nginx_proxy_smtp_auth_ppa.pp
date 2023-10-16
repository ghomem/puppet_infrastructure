# This class adds our nginx PPA with the proxy_smtp_auth feature available
class puppet_infrastructure::nginx_proxy_smtp_auth_ppa (
  $staging            = false,
  $nginx_package_name = 'nginx',
) {

  $bindir = lookup('filesystem::bindir')

  # Add PPA - production or staging
  if ( $staging ) {
    $ppa_name = 'ppa:solidangle/nginx-proxy-smtp-auth-staging'
  } else {
    $ppa_name = 'ppa:solidangle/nginx-proxy-smtp-auth'
  }
  apt::ppa { "${ppa_name}": }

  # check_nginx_proxy_smtp_auth_version script dependencies
  $check_nginx_proxy_smtp_auth_version_deps = ['python3-apt', 'python3-launchpadlib']
  package { $check_nginx_proxy_smtp_auth_version_deps:
    ensure  => present,
    require => Exec['apt_update'],
  }

  # Add script for sysmon checking of our customized nginx package
  $ubuntu_dist = 'kinetic' # the ubuntu version that provides the package version we need
  $ubuntu_arch = 'amd64'
  file { "${bindir}/check_nginx_proxy_smtp_auth_version":
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => Package[$check_nginx_proxy_smtp_auth_version_deps],
    content => template('puppet_infrastructure/nginx_proxy_smtp_auth/check_nginx_proxy_smtp_auth_version.py.erb'),
  }

}

