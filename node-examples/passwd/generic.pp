# base user definitions for all machines
class passwd_base {

  # all fields but username will be dummy if the info is not on the database

  # be sure that default AWS user (not managed via hashman) is not usable - will get an ssh dummy key
  puppet_infrastructure::user_sudoer { 'ubuntu': myname => 'Ubuntu user locked' }

}

# the devops team - all machines
class passwd_devops (
  Array $unmanaged_users = [],
  String $homemode = 'u=rwx,g=rx,o=',
) {

  # all fields but username will be dummy if the info is not on the database
  $users_sudoers_devops = {
    # FIXME: Add devops users here, example:
    # 'testuser'   => { myname => $::testuser_cname,   myhash => $::testuser_pwd_hash,   mykey => $::testuser_ssh_key,   myhomemode => $homemode, },
  }

  puppet_infrastructure::users_sudoers {'devops':
    configs         => $users_sudoers_devops,
    unmanaged_users => $unmanaged_users,
  }

}

# other users we might need
class passwd_others {

}

# the users we need at every machine
class passwd_common (
  Array $unmanaged_users_devops = [],
  String $homemode_users_devops = 'u=rwx,g=rx,o=',
) {

  include passwd_base
  class {'passwd_devops': unmanaged_users => $unmanaged_users_devops, homemode => $homemode_users_devops }
  include passwd_others

}
