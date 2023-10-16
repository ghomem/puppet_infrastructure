### Purpose ########
# This class provides the common files and directories needed to execute linux policies with puppet

### Outputs ########
# - all the needed files and directories needed in
# /usr/local/AS/linux-policies
# - a file to execute the linux policies on user login in
# /etc/xdg/autostart/linux_policies_user.desktop

class puppet_infrastructure::linux_policies_common {

  #Find out the linux policies installation directory
  $localdir = lookup('filesystem::localdir')
  $linux_policies_dir = "${localdir}/linux-policies"

  #Create the linux-policies directory and basic files
  file { "${linux_policies_dir}":
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    ensure  => directory,
    recurse => true,
    source  => "puppet:///modules/puppet_infrastructure/linux-policies/",
  }

  # Files needed to execute the policies on user login
  file { "/etc/xdg/autostart/linux-policies-user.desktop":
    mode      => '0644',
    owner     => 'root',
    group     => 'root',
    content   => template('puppet_infrastructure/linux-policies/autostart.desktop.erb'),
  }
  file { "${linux_policies_dir}/COMMON/execute_linux_policies_user.sh":
    mode      => '0755',
    owner     => 'root',
    group     => 'root',
    content   => template('puppet_infrastructure/linux-policies/execute_linux_policies_user.sh.erb'),
  }

}

