### Purpose ########
# This defined type updates the screen locker settings for a specific user

define puppet_infrastructure::user_kde_lock_screen(
  Integer $screenlock_timeout_minutes = 5,
  Integer $screenlock_grace_minutes   = 0,
) {

  include puppet_infrastructure::user_kde_lock_screen_common

  $myusername = $title
  $bindir = lookup('filesystem::bindir')

  exec { "configure_lock_screen.sh ${myusername}" :
    command => "${bindir}/configure_lock_screen.sh ${screenlock_timeout_minutes} ${screenlock_grace_minutes}",
    user    => $myusername,
    require => File["${bindir}/configure_lock_screen.sh"],
    unless  => "${bindir}/configure_lock_screen.sh ${screenlock_timeout_minutes} ${screenlock_grace_minutes} --check",
  }

}
