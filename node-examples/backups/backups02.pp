node 'backups02' {

  # Basic declarations
  class { 'puppet_infrastructure::node_base':
    filesystem_security => false, # the unprivileged user 'backups' needs to execute the ssh command
  }
  include passwd_common
  include passwd_backups_srv

  # fetches data from the same directory in different remote machines
  puppet_infrastructure::sync { 'remote-machine':
    localdir       => '/home/backups/rsynctest',
    localuser      => 'backups',
    remotedir      => '/directory/to/backup',
    remoteuser     => 'backups',
    hour           => '15',
    minute         => '00',
    hostlist       => 'a.a.a.a:22 b.b.b.b:22 c.c.c.c:22 d.d.d.d:22',
    bwlimit_mbitps => 80,
  }

}
