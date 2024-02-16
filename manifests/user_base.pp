### Purpose ########
# This defined type provides a wrapper with added features for a system user
# It is a base defined type for other classes to use.
define puppet_infrastructure::user_base( $myname = 'Dummy Dummier', $myhash = '', $mykey = 'dummykey', $mygrouplist = [ ], $ignorekey = false, $myppsigs = '', $myppwrapped = '', $myhome = '', String $myhomemode = '', String $user_shell = '/bin/bash') {

  $myusername = $title

  if ( $myhome == '' )
  {
    $myhomedir = "/home/${myusername}"
  }
  else
  {
    $myhomedir = $myhome
  }

  $ecryptdir = "/home/.ecryptfs/${myusername}/.ecryptfs"

  if ( $myhash == '' )
  {
    fail ( 'Can\'t touch this - hash is empty! Where is the user database?' )
  }

  # if the group list is empty or contains only sudo the default applies
  if ( $mygrouplist == [] or $mygrouplist[0] == 'sudo' or $mygrouplist[0] == 'wheel' ){
    $myprimary = $title
  }
  else # otherwise we use the first group on the list as primary
  {
    $myprimary = $mygrouplist[0]
  }

  # we are forced to define this since we added the gid paramter
  # to the user definition (below) for the sake of shared files
  group { $myusername:
    ensure       => present,
  }

  # check if user is locked and/or pass expired

  # random string to concatenate to the dummy ssh key...
  # ... just in case someone can generate the corresponding private key :-)

  $random_string = fqdn_rand_string(30)
  if ( '!' in $myhash ){

    $sshkey = join ( [ 'userlocked', $random_string ] )
    notice("user ${myname} is locked so sshkey will be empty")

  } else {

    if ( $mykey == '' ) {
      $sshkey = join ( [ 'emptykey', $random_string ] )
      notice("user ${myname} has no key so sshkey will be empty")
    }
    else {
      notice("user ${myname} has a key and is not locked so sshkey will be pushed")
      $sshkey = $mykey
    }

  }

  user { $myusername:
  ensure         => present,
  groups         => $mygrouplist ,
  gid            => $myprimary,
  comment        => $myname,
  home           => $myhomedir,
  managehome     => true,
  shell          => $user_shell,
  password       => $myhash,
  purge_ssh_keys => true,
  require        => Group[ $myusername ]
  }

  # We could use accounts::user to manage the home directory permissions,
  # but that requires some time for a careful refactor e.g. regarding
  # the group ip and the SSH key management (see Issue #112).
  # So for the time we stick to the native user resource and thus
  # roll our own code for this:
  if ( $myhomemode != '' ) {
    file { $myhomedir:
      ensure  => directory,
      require => [
        User[$myusername],
      ],
      owner   => $myusername,
      group   => $myprimary,
      mode    => $myhomemode,
    }
  }

  # needed to avoid puppet errors on encrypted homedir scenarios
  if ( $ignorekey == false ) {

    ssh_authorized_key { "${myusername}@puppet" :
    user => $myusername,
    type => 'ssh-rsa',
    key  => $sshkey,
    }

  }

  # just for readability
  $ppsigs = $myppsigs
  $ppwrapped = $myppwrapped

  if( $ppsigs != '' ) and ( $ppwrapped != '' ) {
    notice ("user ${myusername} has passphrase signatures ${ppsigs} and wrapped passphrase ${ppwrapped}" )

    $ppsigs_bin = base64('decode', $ppsigs)
    $ppwrapped_bin = base64('decode', $ppwrapped)

    notice ("user ${myusername} has RAW BINARY passphrase signatures ${ppsigs_bin} and wrapped passphrase ${ppwrapped_bin}" )

    # were are pushing the b64 encoded version as puppet seems not to suport binary content (!)
    # in practice it seems to work but returns an error msg to stdout and an error code to the shell
    # ref ticket: https://tickets.puppetlabs.com/browse/SERVER-1082
    file { "${ecryptdir}/wrapped-passphrase.b64":
    ensure  => 'present',
    content => $ppwrapped,
    mode    => '0600',
    owner   => $myusername,
    group   => $myusername,
    notify  => Exec[ "${ecryptdir}/wrapped-passphrase" ],
    }

    exec { "${ecryptdir}/wrapped-passphrase":
    command => "cat ${ecryptdir}/wrapped-passphrase.b64 |base64 -d > ${ecryptdir}/wrapped-passphrase",
    user    => $myusername,
    path    => [ '/usr/local/bin/', '/bin/', '/usr/bin/' ],
    require => File[ "${ecryptdir}/wrapped-passphrase.b64" ],
    }

  }

}

