### Purpose ########
# This classe provides extra filesystem security by restricting a certain set of commands to a certain group
define puppet_infrastructure::filesystem_sec ( $restricted_cmds = '' , $restricted_group = '' , $restricted_mode = '0750' )
{
  $os_family = $facts['os']['family']
  
  if $restricted_group == '' {
    if $os_family == 'RedHat' {
      $restricted_group = 'wheel'
    } else {
      $restricted_group = 'sudo'
    }
  }

  file { $restricted_cmds:
    owner => root,
    group => $restricted_group,
    mode  => $restricted_mode,
  }

}

