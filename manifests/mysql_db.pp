# Create a MySQL database with a read/write user and, optionally,
# a read-only user. Remote accounts require TLS; network access is
# restricted separately by the node firewall.
#
define puppet_infrastructure::mysql_db (
  String $db_name,
  String $rw_user,
  String $rw_pass,
  Optional[String] $ro_user = undef,
  Optional[String] $ro_pass = undef,
) {

  if ($ro_user and !$ro_pass) or ($ro_pass and !$ro_user) {
    fail('ro_user and ro_pass must either both be provided or both be omitted')
  }

  mysql::db { $db_name:
    dbname      => $db_name,
    user        => $rw_user,
    password    => $rw_pass,
    host        => '%',
    grant       => ['ALL'],
    tls_options => ['SSL'],
    require     => Class['puppet_infrastructure::mysql_server'],
  }

  if $ro_user and $ro_pass {
    mysql_user { "${ro_user}@%":
      ensure        => present,
      password_hash => mysql::password($ro_pass),
      tls_options   => ['SSL'],
      require       => Mysql::Db[$db_name],
    }

    mysql_grant { "${ro_user}@%/${db_name}.*":
      ensure     => present,
      privileges => ['SELECT', 'SHOW VIEW'],
      table      => "${db_name}.*",
      user       => "${ro_user}@%",
      require    => [
        Mysql::Db[$db_name],
        Mysql_user["${ro_user}@%"],
      ],
    }
  }
}
