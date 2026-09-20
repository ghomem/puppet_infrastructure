node 'mysql-server01' {

  include puppet_infrastructure::node_base
  include passwd_common

  $version  = '8.0'
  $base_dir = "/mnt/mysql/${version}"

  $mysql_ip_whitelist = [
    '127.0.0.1',
  ]

  class { 'puppet_infrastructure::mysql_server':
    root_pw   => lookup('db::mysql::root_pw'),
    ssl_chain => 'example-chain.pem',
    ssl_key   => 'example-key.pem',
    ssl_cert  => 'example.pem',
    version   => $version,
    base_dir  => $base_dir,
  }

  puppet_infrastructure::mysql_db { 'example_db':
    db_name => 'example_db',
    rw_user => 'example_rw',
    rw_pass => lookup('db::mysql::example_rw_pass'),
    ro_user => 'example_ro',
    ro_pass => lookup('db::mysql::example_ro_pass'),
  }

  $mysql_ip_whitelist.each |$index, $ip| {
    firewall { "1${index}0 accept mysql from ${ip}":
      proto  => 'tcp',
      dport  => 3306,
      action => 'accept',
      source => $ip,
    }
  }
}
