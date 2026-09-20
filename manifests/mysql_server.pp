# Install and configure a MySQL server using the Ubuntu packages.
#
# Firewall access to TCP/3306 is intentionally managed by the node declaration.
#
class puppet_infrastructure::mysql_server (
  $root_pw,
  $ssl_chain,
  $ssl_key,
  $ssl_cert,
  $version,
  $base_dir,
) {

  $ssl_chain_file = "/etc/ssl/certs/${ssl_chain}"
  $ssl_key_file   = "/etc/ssl/private/${ssl_key}"
  $ssl_cert_file  = "/etc/ssl/certs/${ssl_cert}"
  $data_dir       = "${base_dir}/mysql"

  # The MySQL account is normally created by the Ubuntu package. We create it
  # beforehand because the TLS private key must already have secure ownership
  # when the package starts MySQL for the first time.
  group { 'mysql':
    ensure => present,
    system => true,
  }

  user { 'mysql':
    ensure     => present,
    system     => true,
    gid        => 'mysql',
    home       => '/nonexistent',
    managehome => false,
    shell      => '/bin/false',
    require    => Group['mysql'],
  }

  # Ubuntu confines mysqld with AppArmor. Allow the configured data directory
  # and TLS material before MySQL is installed and started.
  file { '/etc/apparmor.d/local':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { '/etc/apparmor.d/local/usr.sbin.mysqld':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('puppet_infrastructure/mysql/apparmor-local.epp', {
      'data_dir'  => $data_dir,
      'ssl_chain' => $ssl_chain,
      'ssl_key'   => $ssl_key,
      'ssl_cert'  => $ssl_cert,
    }),
    require => File['/etc/apparmor.d/local'],
  }

  file { $ssl_chain_file:
    ensure  => file,
    source  => "puppet:///extra_files/ssl/${ssl_chain}",
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => User['mysql'],
  }

  file { $ssl_cert_file:
    ensure  => file,
    source  => "puppet:///extra_files/ssl/${ssl_cert}",
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => User['mysql'],
  }

  file { $ssl_key_file:
    ensure  => file,
    source  => "puppet:///extra_files/ssl/${ssl_key}",
    owner   => 'mysql',
    group   => 'mysql',
    mode    => '0600',
    require => User['mysql'],
  }

  # Reload the profile before applying MySQL configuration changes.
  exec { 'reload mysql apparmor profile':
    command     => '/usr/sbin/apparmor_parser -r /etc/apparmor.d/usr.sbin.mysqld',
    refreshonly => true,
    subscribe   => File['/etc/apparmor.d/local/usr.sbin.mysqld'],
    onlyif      => '/usr/bin/test -f /etc/apparmor.d/usr.sbin.mysqld',
  }

  class { '::mysql::server':
    package_name            => "mysql-server-${version}",
    package_ensure          => 'present',
    root_password           => $root_pw,
    remove_default_accounts => true,
    restart                 => true,
    override_options        => {
      'mysqld' => {
        'bind-address'             => '0.0.0.0',
        'datadir'                  => $data_dir,
        'ssl-ca'                   => $ssl_chain_file,
        'ssl-cert'                 => $ssl_cert_file,
        'ssl-key'                  => $ssl_key_file,
        'require_secure_transport' => 'ON',
      },
    },
    require => [
      File['/etc/apparmor.d/local/usr.sbin.mysqld'],
      File[$ssl_chain_file],
      File[$ssl_cert_file],
      File[$ssl_key_file],
      Exec['reload mysql apparmor profile'],
    ],
  }

}
