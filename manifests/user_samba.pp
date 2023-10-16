define puppet_infrastructure::user_samba( $myname = 'Dummy Dummier',
                                   $mysmbhash = '',
){
  $username = $title

  $separate_name = split($myname, ' ')
  $first_name    = $separate_name[0]
  $last_name     = $separate_name[-1]

  exec { "create zentyal user: ${username}":
    command => "create-user.pl $username ${first_name} ${last_name} ${mysmbhash}",
    user    => 'root',
    path    => "${localdir}/bin:/usr/bin",
    unless  => "pdbedit -Lw | grep -w ${username}",
  }

  exec { "set ${username} samba hash":
    command => "set-user-samba-hash.sh ${first_name} ${last_name} ${mysmbhash}",
    user    => 'root',
    path    => "${localdir}/bin:/usr/bin",
    unless  => "ldbsearch -H /var/lib/samba/private/sam.ldb sAMAccountName='${username}' unicodepwd | grep -w ${mysmbhash}",
    require => Exec["create zentyal user: ${username}"],
  }
}
