node 'mysql_server03' {

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

  # lower memory configs because this is a staging machine
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
    root_pw               => $rootpw,
    rw_user               => 'userrw',
    rw_hash               => $my_rw_hash,
    ro_user               => 'userro',
    ro_hash               => $my_ro_hash,
    custom_mysqld_configs => $custom_mysqld_configs,
    generate_certificates => false,
  }

}

