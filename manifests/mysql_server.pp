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

  $ssl_dir        = '/etc/mysql/ssl'
  $ssl_chain_file = "${ssl_dir}/${ssl_chain}"
  $ssl_key_file   = "${ssl_dir}/${ssl_key}"
  $ssl_cert_file  = "${ssl_dir}/${ssl_cert}"
  $data_dir       = "${base_dir}/mysql"
  $config_file    = '/etc/mysql/mysql.conf.d/zz-puppet-infrastructure.cnf'

  # Ubuntu confines mysqld with AppArmor. Put the exception in place before
  # the package is installed so its post-installation profile reload includes it.
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
      'data_dir'       => $data_dir,
      'ssl_chain_file' => $ssl_chain_file,
      'ssl_key_file'   => $ssl_key_file,
      'ssl_cert_file'  => $ssl_cert_file,
    }),
    require => File['/etc/apparmor.d/local'],
  }

  # Let the Ubuntu package install and initialize its default environment
  # before enabling the custom datadir configuration. puppetlabs-mysql will
  # initialize $data_dir after the package is installed.
  class { '::mysql::server':
    package_name            => "mysql-server-${version}",
    package_ensure          => 'present',
    root_password           => $root_pw,
    remove_default_accounts => true,
    manage_config_file      => false,
    restart                 => false,
    override_options        => {
      'mysqld' => {
        'datadir' => $data_dir,
      },
    },
  }

  File['/etc/apparmor.d/local/usr.sbin.mysqld']
    -> Package['mysql-server']

  file { $ssl_dir:
    ensure  => directory,
    owner   => 'root',
    group   => 'mysql',
    mode    => '0750',
    require => Package['mysql-server'],
  }

  file { $ssl_chain_file:
    ensure  => file,
    source  => "puppet:///extra_files/ssl/${ssl_chain}",
    owner   => 'root',
    group   => 'mysql',
    mode    => '0644',
    require => File[$ssl_dir],
  }

  file { $ssl_cert_file:
    ensure  => file,
    source  => "puppet:///extra_files/ssl/${ssl_cert}",
    owner   => 'root',
    group   => 'mysql',
    mode    => '0644',
    require => File[$ssl_dir],
  }

  file { $ssl_key_file:
    ensure  => file,
    source  => "puppet:///extra_files/ssl/${ssl_key}",
    owner   => 'root',
    group   => 'mysql',
    mode    => '0640',
    require => File[$ssl_dir],
  }

  exec { 'reload mysql apparmor profile':
    command     => '/usr/sbin/apparmor_parser -r /etc/apparmor.d/usr.sbin.mysqld',
    refreshonly => true,
    subscribe   => File['/etc/apparmor.d/local/usr.sbin.mysqld'],
    require     => Package['mysql-server'],
    onlyif      => '/usr/bin/test -f /etc/apparmor.d/usr.sbin.mysqld',
  }

  # Apply our runtime settings only after puppetlabs-mysql has initialized
  # the custom data directory.
  file { $config_file:
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('puppet_infrastructure/mysql/server.cnf.epp', {
      'data_dir'       => $data_dir,
      'ssl_chain_file' => $ssl_chain_file,
      'ssl_key_file'   => $ssl_key_file,
      'ssl_cert_file'  => $ssl_cert_file,
    }),
    require => [
      Mysql_datadir[$data_dir],
      File[$ssl_chain_file],
      File[$ssl_cert_file],
      File[$ssl_key_file],
      Exec['reload mysql apparmor profile'],
    ],
    notify => Service['mysqld'],
  }

  File[$config_file] -> Service['mysqld']
}
