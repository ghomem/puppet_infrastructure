### Purpose ########
# This defined resource configures ssh-server to restrict the given user to only use SFTP,
# only in the given folder, and only from the given IP(s).
### Warning ########
## 1
##   We do not manage the user here, neither the directory, and neither the parent (root jail) directories.
## 2
##   Notice that puppet_infrastructure restricts ssh access to certain groups so to allow SFTP access the user
##   needs to belong to a group that allows for that. Set the corresponding hiera key e.g. to
##   examplehostname::ssh::othergroups: 'sftp_in sftp_out'
## 3
##   If you need to allow the SFTP acess with password auth,
##   you do NOT need to allow general SSH password authentication.
##   Setting this for the SFTP jail is enough (see the defined type parameters below).
### Justifications #
# We do not use the puppet forge module puppet-sftp_jail just because it does not allow to add IP restrictions.
# But it is a promising alternative to be considered (e.g. if IP restrictions are in the future implemented via firewall).
### Dependencies ###
# The given directory exists (notice read&write permission are those given to the user/group as per linux permissions)
# and only root has write access to parent folders and others have execution permissions (ssh-server sftp-server requirement)
define puppet_infrastructure::sftp_only(
  # Mandatory arguments
  String $user_name,
  # if the array is empty conections from any IP are allowed
  Array  $ip_whitelist,
  String $directory,
  # Option arguments
  # By default we use a umask to remove all permissions for others when creating files
  String $umask = '007',
  Enum['yes', 'no'] $password_authentication = 'no',
) {

  # Get the filepath of the parent directory
  $parent = dirname($directory)
  # Get the name of the (leaf) subdirectory
  $subdirectory = basename($directory)

  # parse the IPs lists into strings if ip_whitelist is not empty
  # if ip_whitelist is empty the ip_whitestring will be a string that allows any connection (*)
  if ($ip_whitelist == []) {
    $ip_whitestring = '*'
  }
  else {
    $ip_whitestring = join($ip_whitelist, ',')
    $ip_except_whitestring = join($ip_whitelist, ',!')
  }

  # declare the allow block
  ssh::server::match_block { "${user_name}, Address ${ip_whitestring}":
    type    => 'User',
    options => {
      'ChrootDirectory'        => $parent,
      # Place the user in the subdir and with the given umask
      'ForceCommand'           => "internal-sftp -d ${subdirectory} -u ${umask}",
      'PasswordAuthentication' => $password_authentication,
      'AllowTcpForwarding'     => 'no',
      'X11Forwarding'          => 'no',
    }
  }

  # Deny block is only declared if ip_whitelist is not empty
  if ($ip_whitelist != []) {
    # declare the deny block
    # SECURITY WARNING: the deny block must cover all cases not in the allow block
    # or else the user will get the general config when using some other IP!!!
    ssh::server::match_block { "${user_name}, Address *,!${ip_except_whitestring}":
      type    => 'User',
      options => {
        'DenyUsers' => $user_name,
      }
    }
  }
}
