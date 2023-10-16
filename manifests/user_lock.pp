### Purpose ########
# This class locks an existing user

### Dependencies ###
# classes: puppet_infrastructure::hashman_base
define puppet_infrastructure::user_lock( ){

  $myuser = $title
  $hashmandir = lookup('hashman::bindir')

  exec { "user_lock_${myuser}":
  # the last part is to avoid E_ERR on already locked users
  command => "${hashmandir}/common/pp_auth.py lock ${myuser} DUMMYARG; exit 0",
  require =>  Class[ 'puppet_infrastructure::hashman_base' ],
  }

}
