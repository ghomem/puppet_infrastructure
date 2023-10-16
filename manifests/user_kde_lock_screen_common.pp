### Purpose ########
# This class provides the screen locker settings script

class puppet_infrastructure::user_kde_lock_screen_common {

  $bindir = lookup('filesystem::bindir')

  file { "${bindir}/configure_lock_screen.sh":
    owner  => root,
    group  => root,
    mode   => '0755',
    source => 'puppet:///modules/puppet_infrastructure/user_kde_lock_screen/configure_lock_screen.sh',
  }

}
