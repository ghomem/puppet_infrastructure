node 'backups04' {

  # Basic declarations
  include puppet_infrastructure::node_base
  include passwd_common

  $bindir = lookup('filesystem::bindir')

  # performs backups of a local directory keeping 7 days of tarball copies
  puppet_infrastructure::backup { 'backup' :
    basedir  => '/directory/to/backup',
    prefix   => 'backup-file',
    backdir  => '/home/backups/localbackups',
    ndays    => 7,
    bindir   => $bindir,
  }

}
