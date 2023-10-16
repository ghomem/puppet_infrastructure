### Purpose ########
# This defined type updates the screen locker settings for a specific user

define puppet_infrastructure::user_kde_lock_screen(Integer $mytimeout = 5, Integer $mylockgrace = 5) {

  include puppet_infrastructure::user_kde_lock_screen_common

  $myusername = $title
  $bindir = lookup('filesystem::bindir')

  exec { "configure_lock_screen.sh ${myusername}" :
    command  => "${bindir}/configure_lock_screen.sh ${mytimeout} ${mylockgrace}",
    user     => $myusername,
  }

}
