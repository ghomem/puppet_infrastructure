# This class creates:
#
# 1. a working mariadb server
# 2. with a root@localhost user that can't access from the outside
# 3. and 2 other users that can access from any host
#
# The users that can access from any host are created with an ed25519 hash
# that can be generated on a Mariadb server with this command
#
# mysql -u SOMEUSER -p -e 'SELECT ed25519_password("reallyGoodPassword");'
#
# Those users can only connect using ssl (ex: --ssl flag on the command line)
#
# Notes: 
# 
# https://mariadb.com/kb/en/secure-connections-overview/
# https://mariadb.com/kb/en/authentication-plugin-ed25519/
# SELECT user,host,password,authentication_string,plugin FROM mysql.user;
#
# Supports Ubuntu >= 18.04. For Ubuntu 18.04 we need to run
#
# sudo mysql -u root -e 'UPDATE mysql.user SET plugin="" where user="root"; FLUSH PRIVILEGES;'
#
# before we can use the mysql root user without sudo.

class puppet_infrastructure::mysql_server ( 
  $root_pw,
  $rw_user = undef,
  $rw_hash = undef,
  $ro_user = undef,
  $ro_hash = undef,
  $custom_mysqld_configs = {},
  $custom_mariadb_configs = {}, 
  Boolean $generate_certificates = true,
) {

  $ssl_dir      = '/etc/mysql/certificates/'
  $organization = lookup('db::organization')
  $cname        = lookup('db::cname')
  $email        = lookup('db::email')
  $bindir       = lookup('filesystem::bindir')

  $my_mariadb_options = {
    'plugin_load_add' => 'auth_ed25519',
  }

  $my_mysqld_options = {
    'ssl'                      => 'true',
    'ssl-cert'                 => "${ssl_dir}/server-cert.pem",
    'ssl-key'                  => "${ssl_dir}/server-key.pem",
    'ssl-ca'                   => "${ssl_dir}/ca.pem",
    'require_secure_transport' => 'ON',
    'bind-address'             => "0.0.0.0",
  }

  $temp_mysqld_options = $my_mysqld_options + $custom_mysqld_configs
  $temp_mariadb_options = $my_mariadb_options + $custom_mariadb_configs

  $full_override_options = {
    'mariadb' => $temp_mariadb_options,
    'mysqld'  => $temp_mysqld_options,
  }

  notify { "Produced configs: ${full_override_options}" : loglevel => 'debug' }

  $major_release = $facts['os']['release']['major']

  # needed for ed25519 auth client side
  if $major_release == '18.04' {
    $client_pkg_name = 'libmariadbclient18'
  }
  else {
    # 20.04 and 22.04
    $client_pkg_name = 'libmariadb3'
  }

  class {'::mysql::client':
    package_name    => $client_pkg_name,
    bindings_enable => false,
  }

  file { $ssl_dir:
    ensure => directory,
    owner  => root,
    group  => root,
    mode   => '0755'
  }

  if ( $generate_certificates ) {

    file { "$bindir/deploy_self_signed_certificates.sh":
      owner   => root,
      group   => root,
      mode    => '0755',
      content => template('puppet_infrastructure/mysql/deploy_self_signed_certificates.sh.erb'),
      require => File[ $ssl_dir ]
    }

    exec { "generate the ssl certificates, sign them and deploy them at $ssl_dir":
      command => "$bindir/deploy_self_signed_certificates.sh",
      require => File[ "$bindir/deploy_self_signed_certificates.sh" ]
    }

  }
  else {

      file { "$ssl_dir/server-cert.pem":
        source  => 'puppet:///extra_files/ssl/db/server-cert.pem',
        owner   => root,
        group   => root,
        mode    => '0644',
        require => File[ $ssl_dir ] 
      }

      file { "$ssl_dir/server-key.pem":
        source  => 'puppet:///extra_files/ssl/db/server-key.pem',
        owner   => root,
        group   => root,
        mode    => '0644',
        require => File[ $ssl_dir ] 
      }

      file { "$ssl_dir/ca.pem":
        source  => 'puppet:///extra_files/ssl/db/ca.pem',
        owner   => root,
        group   => root,
        mode    => '0644',
        require => File[ $ssl_dir ] 
      }

  }

  # Prepare hashmap with the users to include in the database
  if ($rw_user and !$rw_hash) {
    fail("Error: Please provide a value for the 'rw_hash' variable, if it's not passed you won't be able to use the database with this user.")
  }
  if ($rw_user and $rw_hash) {
    $rw_user_map       = { "${rw_user}@%"     => { ensure => 'present', password_hash => $rw_hash, plugin => 'ed25519', tls_options => [ 'SSL' ], } }
    $rw_user_grant_map = { "${rw_user}@%/*.*" => { ensure => 'present', options => ['GRANT'], privileges => ['ALL'], table => '*.*', user => "${rw_user}@%", } }
  } else {
    $rw_user_map       = {}
    $rw_user_grant_map = {}
  }
  if ($ro_user and !$ro_hash) {
    fail("Error: Please provide a value for the 'ro_hash' variable, if it's not passed you won't be able to use the database with this user.")
  }
  if ($ro_user and $ro_hash) {
    $ro_user_map       = { "${ro_user}@%"     => { ensure => 'present', password_hash => $ro_hash, plugin => 'ed25519', tls_options => [ 'SSL' ], } }
    $ro_user_grant_map = { "${ro_user}@%/*.*" => { ensure => 'present', options => ['GRANT'], privileges => ['SELECT','SHOW VIEW'], table => '*.*', user => "${ro_user}@%", } }
  } else {
    $ro_user_map       = {}
    $ro_user_grant_map = {}
  }
  $db_users  = $rw_user_map       + $ro_user_map
  $db_grants = $rw_user_grant_map + $ro_user_grant_map

  # Provide the database server with the users described above
  class { '::mysql::server':
    package_name            => 'mariadb-server',
    root_password           => $root_pw,
    remove_default_accounts => true,
    restart                 => true,
    users                   => $db_users,
    grants                  => $db_grants,
    override_options        => $full_override_options,
  }

  file { '/var/log/mysql':
    ensure  => 'directory',
    owner   => 'mysql',
    group   => 'adm',
    mode    => '0755',
    require => Package['mysql-server'],
  }
}

