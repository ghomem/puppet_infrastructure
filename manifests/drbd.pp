### Purpose ########
# This class sets up DRDB in an active/passive configuration

### Dependencies ###
# classes: puppet_infrastructure::user_base

# DRBD - READ THE INLINE COMMENTS -
# IMPORTANT TO UNDERSTAND PUPPET RUN HANG
# used for zimbra replication so it prevents its start on boot

class puppet_infrastructure::drbd (
    $active_host   = undef,
    $passive_host  = undef,
    $active_ip     = undef,
    $passive_ip    = undef,
    $disk          = undef,
    $ha_primary    = false,
    $initial_setup = false,
  ) {

  service { 'zimbra':
    enable => false,
  }

  # kemra102-elrepo
  class { '::elrepo': }

  # voxpupuli-puppet-drbd
  # no recent forge release so: sudo git clone https://github.com/voxpupuli/puppet-drbd.git drbd
  class { 'drbd':
    package_name => 'drbd90-utils'
  }

  Package { 'kmod-drbd90':
    ensure => installed,
    before => Exec['modprobe drbd']
  }

  # this config is static with 2 hosts
  # the first to apply this resource will hang on drbd service start
  # until the second node applies it to and it can reach it.
  # Do it in sequence to prevent timeouts!
  drbd::resource { 'drbd':
    host1         => $active_host,
    host2         => $passive_host,
    ip1           => $active_ip,
    ip2           => $passive_ip,
    disk          => $disk,
    port          => '7789',
    device        => '/dev/drbd0',
    manage        => true,
    protocol      => 'A',
    fs_type       => 'xfs',
    mountpoint    => '/opt/zimbra',
    verify_alg    => 'sha1',
    ha_primary    => $ha_primary,
    initial_setup => $initial_setup,
  }

}
