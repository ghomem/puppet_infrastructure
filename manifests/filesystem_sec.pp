### Purpose ########
# This classe provides extra filesystem security by restricting a certain set of commands to a certain group
define puppet_infrastructure::filesystem_sec ( $restricted_cmds = '' , $restricted_group = 'sudo' , $restricted_mode = '0750' )
{

  file { $restricted_cmds:
    owner => root,
    group => $restricted_group,
    mode  => $restricted_mode,
  }

}

