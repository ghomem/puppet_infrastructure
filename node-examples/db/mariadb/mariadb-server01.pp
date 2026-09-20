node 'mariadb-server01' {

  # This is an initial node declaration to get started with a MySQL dabase server

  # Basic declarations
  include puppet_infrastructure::node_base
  include passwd_common

  # To make the variable below works, add this line to 
  # /etc/puppetlabs/code/environments/production/data/common.yaml:
  #
  # db::mariadb::root_pw: 'Insert here a strong password for the root user'
  #
  # This will restrict the database access to the given user and password

  $root_pw = lookup('db::mariadb::root_pw')

  # The MariaDB database server
  class { 'puppet_infrastructure::mariadb_server':
    root_pw => $root_pw,
  }

}
