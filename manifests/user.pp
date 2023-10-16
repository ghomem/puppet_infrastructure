### Purpose ########
# This class defines a normal user not belonging to any special groups

### Dependencies ###
# classes: puppet_infrastructure::user_base
define puppet_infrastructure::user( $myname = 'Dummy Dummier', $myhash = '', $mykey = 'dummykey', $mygrouplist = [ ], $myhome = '', String $myhomemode = '', String $user_shell = '/bin/bash') {

  puppet_infrastructure::user_base { $title : myname => $myname, myhash => $myhash , mykey => $mykey, mygrouplist => $mygrouplist, myhome => $myhome, myhomemode => $myhomemode, user_shell => $user_shell }

}

