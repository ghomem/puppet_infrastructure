### Purpose ########
# This class provides share mount configuration to a generic desktop node for a specific user

# ‘$USER’ is the default value of auth_user and is included literally on the shares.erb.template where it gets expanded as a shell variable.
define puppet_infrastructure::mount_shares_desktop ($username = $title, $suffix = '',$shares = [], $explorer = 'True' , $symlinks = 'False', $delay = '0.5', $cache = 'True', $auth_user = '$USER' )
{
  $myusername = $username
  $desktop_dir = "/home/${myusername}/Desktop"
  file { "${desktop_dir}/shares${suffix}-mount.sh":
  mode    => '0755',
  owner   => 'root',
  group   => 'root',
  content => template('puppet_infrastructure/shares/shares.sh.erb'),
  }

  file { "${desktop_dir}/shares${suffix}-unmount.sh":
  mode    => '0755',
  owner   => 'root',
  group   => 'root',
  content => template('puppet_infrastructure/shares/unmount-shares.sh.erb'),
  }

}
