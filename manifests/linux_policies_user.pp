### Purpose ########
# This defined type composes the <USERNAME>.sh script to execute the policies of a specific user

### Inputs ########
# - the user name 
# - an array of strings with the policies to be executed by the given user

### Outputs ########
# - a file with the linux policies available in:
# /usr/local/AS/linux-policies/USER/<USERNAME>.sh

### Dependencies ###
# classes: puppet_infrastructure::linux_policies_common

define puppet_infrastructure::linux_policies_user (
  # the user name
  $username,
  # an array of strings providing the policies to be executed by this user
  $policies,
) {

  #Find out the policies scripts full paths
  $localdir = lookup('filesystem::localdir')
  $linux_policies_dir = "${localdir}/linux-policies"
  $policies_script_exec = "${linux_policies_dir}/COMMON/execute_linux_policies_user.sh"
  $policies_script = "${linux_policies_dir}/USER/${username}.sh"
  $policies_script_tmp = "${linux_policies_dir}/TMP/${username}.sh.tmp"

  #Create the policies script <username>.sh.tmp
  file { "${policies_script_tmp}":
    mode      => '0700',
    owner     => $username,
    group     => $username,
    show_diff => false,
    loglevel  => debug, # We need to hide the reporing on agent run, otherwise the agent
                        # will report every time that this file changed because this file
                        # is generated dinamically.
    backup    => false, # Avoid this file being 'filebucketed' so we get rid of another
                        # couple of lines of noise in the agent run, this setting should
                        # do no harm for this particular file, because it's just a
                        # temporary file.
    content   => template('puppet_infrastructure/linux-policies/puppet_header.sh.erb')
  }

  #Add the policies to <username>.sh.tmp for this particular user
  $policies.each |$i, String $policy| {
    file_line { "${policies_script_tmp}_${i}":
      ensure    => present,
      path      => "${policies_script_tmp}",
      loglevel  => debug, # hide the reporting on the agent run to have a cleaner stdout
      line      => $policy,
      require   => File["${policies_script_tmp}"],
      before    => File["${policies_script}"],
    }
  }

  #Copy the policies script to its final destination
  file { "${policies_script}":
    mode      => '0700',
    owner     => $username,
    group     => $username,
    source    => $policies_script_tmp,
  }

  #Delete the temporary file once we are done
  tidy { "${policies_script_tmp}":
    path => "${policies_script_tmp}"
  }

  #Execute the policies on agent run if the user is logged in
  exec { "Execute linux policies for: ${username}" :
    command     => "${policies_script_exec} puppet-agent",
    user        => $username,
    environment => [ "HOME=/home/${username}" ],
  }

}
