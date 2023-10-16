node 'mysql-server01' {

  # This is an initial node declaration to get started with a MySQL dabase server

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

  # The MySQL database server
  class { 'puppet_infrastructure::mysql_server':
    root_pw => $root_pw,
  }

}
