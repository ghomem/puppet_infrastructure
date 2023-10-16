node 'mysql-client01' {

  include puppet_infrastructure::node_base
  include passwd_common

  package { 'mariadb-client':
    ensure => 'installed',
  }

}
