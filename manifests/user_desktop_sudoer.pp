### Purpose ########
# This defined type defines a desktop sudoer user

### Dependencies ###
# defined type: puppet_infrastructure::user_base
# defined type: puppet_infrastructure::user_kde_lock_screen
define puppet_infrastructure::user_desktop_sudoer( $myname = 'Dummy Dummier', $myhash = '', $mykey = 'dummykey', $mygrouplist = [ ], $ignorekey = false, $myppsigs = '', $myppwrapped = '', $mytimeout = 5,  $mylockgrace = 5, String $myhomemode = '', String $user_shell = '/bin/bash') {

  $grouplist = flatten( [ $mygrouplist, [ $title, 'cdrom', 'dip', 'plugdev', 'lp', 'lpadmin', 'sambashare', 'adm', 'sudo' ] ] )
  puppet_infrastructure::user_base { $title : myname => $myname, myhash => $myhash , mykey => $mykey, mygrouplist => $grouplist, ignorekey => $ignorekey, myppsigs => $myppsigs, myppwrapped => $myppwrapped, myhomemode => $myhomemode, user_shell => $user_shell }

  puppet_infrastructure::user_kde_lock_screen { $title : mytimeout => $mytimeout, mylockgrace => $mylockgrace }

}
