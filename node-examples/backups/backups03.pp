node 'backups03' {

  # Basic declarations
  include puppet_infrastructure::node_base
  include passwd_common
  include puppet_infrastructure::backup_rsnapshot_pre

  # performs backups of a local directory, keeping 30 days of rsnapshots copies
  $mynode1 = 'hostname'
  puppet_infrastructure::backup_rsnapshot { "${mynode1}":
    basedir => "/directory/to/backup",
    prefix  => 'testrsnapshot',
    backdir => "/home/backups/rsnapshottest",
    user    => backups,
    hour    => '03',
    minute  => '0',
    ndays   => 30,
  }

}
