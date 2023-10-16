node 'mysql-server-node' {

  # Basic declarations
  include puppet_infrastructure::node_base
  include passwd_common

  # To make the variable below works, add this line to
  # /etc/puppetlabs/code/environments/production/data/common.yaml:
  #
  # db::mysql::root_pw: 'Insert here a strong password for the root user'
  #
  # This will restrict the database access to the given user and password

  $root_pw = lookup('db::mysql::root_pw')

  # lower memory configs in case of a staging machine
  $custom_mysqld_configs = {
      'innodb_buffer_pool_size' => '1G',
      'tmp_table_size'          => '32M',
      'max_heap_table_size'     => '32M',
      'query_cache_type'        => '1',
      'query_cache_size'        => '32M',
      'datadir'                 => '/storage/mysql',
      'sql_mode'                => 'ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION',
  }

  # the users created here are MySQL server users not pre-assgined to any db
  # they are for the team to administer the server
  # the ed25519 hashes can be generated with this command
  # mysql -u root -p -e 'SELECT ed25519_password("reallyGoodPassword");'
  $my_ro_hash = 'this is the mariadb ed25519 hash of a read only operations user'
  $my_rw_hash = 'this is the mariadb ed25519 hash of a read write operations user'

  # the users created here are MySQL server users not pre-assgined to any db
  # they are for the team to administer the server
  class { 'puppet_infrastructure::mysql_server':
    root_pw               => $root_pw,
    rw_user               => 'userrw',
    rw_hash               => $my_rw_hash,
    ro_user               => 'userro',
    ro_hash               => $my_ro_hash,
    custom_mysqld_configs => $custom_mysqld_configs,
    generate_certificates => true,
  }

  $dbuser = 'remote_username' # Specify the remote username
  $dbpass = 'remote_user_password' # Specify the password for the remote user
  $host   = 'y.y.y.y' # The IP address of the host that will be granted access to this database

  mysql::db { 'database_name': # Specify the name of the database
    user     => $dbuser, # The username for the database
    password => $dbpass, # The password for the database user
    host     => $host,
    grant    => [ 'SELECT', 'SHOW VIEW' ], # Specify the permissions to grant this user
    require  => Class['puppet_infrastructure::mysql_server'],
  }

  # Create a firewall rule for this host to allow incoming connections to the MySQL server
  firewall { '200 accept mysql client': proto  => 'tcp', dport  => 3306, action => 'accept', source => $host, }

}
