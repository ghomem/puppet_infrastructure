### Purpose ########
# Base profile for Kubuntu desktops:
# - Centrally managed package updates (cron via apt helper)
# - 5-minute KDE screensaver lock (per user)
# - Centrally managed firewall
# - Rsyslog client → central log server (TLS handled by rsyslog_*)

class puppet_infrastructure::node_base_desktop (
  Boolean $customize_syslog_mode          = false,
  String  $syslog_mode                    = 'u=rw,g=r,o=',
  Array[String] $apt_surface_list         = [],   # empty → builtin desktop list
  Boolean $firewall_strict_purge          = true,
  Array[String] $firewall_ignore_patterns = [],

  # logging target (required for desktops that should ship logs)
  String  $log_target,
  String  $log_target_ip,
  Integer $log_port                       = 6514,
  Boolean $log_check_names                = false,

  # screensaver (KDE) per desktop user
  Array[String] $screenlock_users         = [],
  Integer $screenlock_timeout_minutes     = 5,
  Integer $screenlock_grace_minutes       = 0,
) {

  # Base pkgs; avoid OS-native unattended mechanisms for determinism
  class { 'puppet_infrastructure::packages_base':
    unattended_upgrades => false,
  }

  include puppet_infrastructure::ssh_secure

  class { 'puppet_infrastructure::firewall_secure':
    strict_purge    => $firewall_strict_purge,
    ignore_patterns => $firewall_ignore_patterns,
  }
  include puppet_infrastructure::firewall_ipv6_drop_policy

  class { 'puppet_infrastructure::filesystem_base_desktop':
    customize_syslog_mode => $customize_syslog_mode,
    syslog_mode           => $syslog_mode,
  }

  # APT helpers tailored for desktops
  class { 'puppet_infrastructure::filesystem_apt':
    apt_surface_list => $apt_surface_list,
    server_mode      => false,
  }

  # Nightly relevant updates (desktops only)
  $localdir = lookup('filesystem::localdir')
  cron { 'apt_update_relevant_daily':
    command => "${localdir}/bin/apt-update-relevant.sh",
    user    => 'root',
    hour    => '02',
    minute  => '00',
  }

  # Central logs (TLS handled by rsyslog_base + client template)
  class { 'puppet_infrastructure::rsyslog_client':
    target      => $log_target,
    target_ip   => $log_target_ip,
    port        => $log_port,
    check_names => $log_check_names,
  }

  $screenlock_users.each |String $u| {
    puppet_infrastructure::user_kde_lock_screen { $u:
      mytimeout   => $screenlock_timeout_minutes,
      mylockgrace => $screenlock_grace_minutes,
    }
  }

  # Desktops run puppet directly
  service { 'puppet':
    ensure   => running,
    enable   => true,
    provider => systemd,
  }
}
