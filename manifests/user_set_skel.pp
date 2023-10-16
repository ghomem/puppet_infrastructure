### Purpose ########
# This class imposes specific files on user directories if and only if
# they exists on a user specific directory at the pupet master

# ** FIXME UNTESTED ON PUPPET5 **

define puppet_infrastructure::user_set_skel( $myusername = 'dummyuser' ) {

  # the list of files that might possibly exist for distribution on our side
  # TODO - externalize this list
  $skelfiles = [ '.bashrc', '.ssh/id_rsa', '.ssh/id_rsa.pub' ]

  # the basedir, because the file function doesn't take pupet://
  $filespath='/etc/puppet/files/'

  # strip the resourcename from it's source of uniquenes, the suffix
  $myfilename = basename( $name , "_${myusername}" )
  $parentdir = dirname ( $name )

  $dirpath = "${filespath}/skel/${myusername}/${parentdir}/"
  $mypath = "${dirpath}/${myfilename}"

  # based on a clever hack from Stackoverflow
  # http://stackoverflow.com/questions/20551780/how-do-i-make-puppet-copy-a-file-only-if-source-exists
  # the second argument is to avoid an error for non-existing files, remove it to debug
  $aux = file( $mypath , '/dev/null')

  if( $aux != '' ) {

    $localdir = "/home/${myusername}/${parentdir}"
    # it is not pretty to use exec but multiple files inside the same dir would cause resource redeclaration
    if ( $parentdir != '.'  )  {
      exec { "${parentdir}_${mypath}":
      command => "mkdir -p ${localdir}; chown ${myusername}:${myusername} ${localdir}; chmod 700 ${localdir}",
      path    => '/bin/:/usr/bin/'
      }
    }

    # the file is unique so we use a normal puppet resource
    file { $name:
    path    => "${localdir}/${myfilename}",
    mode    => '0600',
    owner   => $myusername,
    group   => $myusername,
    source  => "puppet:///extra_files/skel/${myusername}/${parentdir}/${myfilename}",
    require => User[ $myusername ]
    }
  }

}
