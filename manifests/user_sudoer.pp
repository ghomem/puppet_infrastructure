### Purpose ########
# This class defines a sudoer user

### Dependencies ###
# classes: puppet_infrastructure::user_base
define puppet_infrastructure::user_sudoer( $myname= 'Dummy Dummier', $myhash= 'dummyhash', $mykey = 'dummykey', $mygrouplist = [ ], $ignorekey = false, $myppsigs = '', $myppwrapped = '', $myhome = '', String $myhomemode = '', String $user_shell = '/bin/bash') {

  if $facts['os']['family'] == 'RedHat' {
    $grouplist = flatten( [ $mygrouplist, [ 'wheel' ] ] )
  } else {
    $grouplist = flatten( [ $mygrouplist, [ 'sudo' ] ] )
  }

  puppet_infrastructure::user_base { $title : myname => $myname, myhash => $myhash , mykey => $mykey, mygrouplist => $grouplist, ignorekey => $ignorekey, myppsigs => $myppsigs, myppwrapped => $myppwrapped, myhome => $myhome, myhomemode => $myhomemode, user_shell => $user_shell }

}
