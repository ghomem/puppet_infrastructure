### Purpose ########
# Base profile for Ubuntu/Kubuntu desktop nodes:
# - Centrally managed package/update helpers
# - Centrally managed firewall
# - Rsyslog client → central log server
# - Optional KDE per-user screen lock
# - Optional GNOME system-wide screen lock policy

class puppet_infrastructure::node_base_desktop (
  Boolean $customize_syslog_mode              = false,
  String  $syslog_mode                        = 'u=rw,g=r,o=',
  Array[String] $apt_surface_list             = [],   # empty → builtin desktop list
  Boolean $firewall_strict_purge              = true,
  Array[String] $firewall_ignore_patterns     = [],

  # SSH policy
  Boolean $password_authentication            = false,
  Boolean $ssh_allow_root_login               = false,
  Integer $ssh_port                           = 22,

  # logging target, required for desktops that should ship logs
  String  $log_target,
  Optional[String] $log_target_ip             = undef,
  Integer $log_port                           = 6514,
  Boolean $log_check_names                    = false,

  # KDE screen lock, per desktop user
  Array[String] $screenlock_users             = [],
  Integer $screenlock_timeout_minutes         = 5,
  Integer $screenlock_grace_minutes           = 0,

  # GNOME screen lock, system-wide dconf policy
  Boolean $manage_gnome_screenlock            = false,
  Integer $gnome_screenlock_idle_delay_seconds = 300,
  Integer $gnome_screenlock_lock_delay_seconds = 0,
) {

  # Base packages are intentionally part of the desktop baseline.
  # On Ubuntu/Debian this provides iptables-persistent/netfilter-persistent,
  # which is required for firewall rules to survive reboot.
  class { 'puppet_infrastructure::packages_base':
    unattended_upgrades => false,
  }

  class { 'puppet_infrastructure::ssh_secure':
    password_authentication => $password_authentication,
    root_login              => $ssh_allow_root_login,
    port                    => $ssh_port,
  }

  class { 'puppet_infrastructure::filesystem_base_desktop':
    customize_syslog_mode => $customize_syslog_mode,
    syslog_mode           => $syslog_mode,
  }

  class { 'puppet_infrastructure::firewall_secure':
    strict_purge    => $firewall_strict_purge,
    ignore_patterns => $firewall_ignore_patterns,
  }

  include puppet_infrastructure::firewall_ipv6_drop_policy

  # Make the firewall baseline dependency explicit.
  Class['puppet_infrastructure::packages_base'] -> Class['puppet_infrastructure::firewall_secure']

  # APT helpers tailored for desktops.
  class { 'puppet_infrastructure::filesystem_apt':
    apt_surface_list => $apt_surface_list,
    server_mode      => false,
  }

  # Nightly relevant updates, desktops only.
  $localdir = lookup('filesystem::localdir')
  cron { 'apt_update_relevant_daily':
    command => "${localdir}/bin/apt-update-relevant.sh",
    user    => 'root',
    hour    => '02',
    minute  => '00',
  }

  # Central logs.
  class { 'puppet_infrastructure::rsyslog_client':
    target      => $log_target,
    target_ip   => $log_target_ip,
    port        => $log_port,
    check_names => $log_check_names,
  }

  # KDE lock screen policy is per user.
  $screenlock_users.each |String $u| {
    puppet_infrastructure::user_kde_lock_screen { $u:
      mytimeout   => $screenlock_timeout_minutes,
      mylockgrace => $screenlock_grace_minutes,
    }
  }

  # GNOME lock screen policy is system-wide.
  if $manage_gnome_screenlock {
    class { 'puppet_infrastructure::gnome_lock_screen':
      idle_delay_seconds => $gnome_screenlock_idle_delay_seconds,
      lock_delay_seconds => $gnome_screenlock_lock_delay_seconds,
    }
  }

  # Desktops run Puppet directly.
  service { 'puppet':
    ensure   => running,
    enable   => true,
    provider => systemd,
  }
}
