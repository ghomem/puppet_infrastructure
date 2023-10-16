class puppet_infrastructure::nginx_default_removal {
  # This removes the default config file from the package
  file { '/etc/nginx/sites-enabled/default':
    ensure => absent,
  }
}
