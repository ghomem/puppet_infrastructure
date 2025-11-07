### Purpose ########
# This class provides basic desirable properties of a domain based desktop node
class puppet_infrastructure::node_base_domain_desktop (
  Boolean $customize_syslog_mode = false,
  String $syslog_mode            = 'u=rw,g=r,o=',
  $apt_surface_list = [], # if empty it will default to a builtin list
) {

  class { 'puppet_infrastructure::packages_base': unattended_upgrades => true }
  class { 'puppet_infrastructure::ssh_secure': password_authentication => true }
  include puppet_infrastructure::firewall_secure
  include puppet_infrastructure::firewall_ipv6_drop
  class { 'puppet_infrastructure::filesystem_base_desktop':
    customize_syslog_mode => $customize_syslog_mode,
    syslog_mode           => $syslog_mode,
  }
  class { 'puppet_infrastructure::filesystem_apt':
    apt_surface_list  => $apt_surface_list,
    server_mode       => false,
  }

  include ::ntp

  # desktops run puppet directly, not via sysmon
  service { 'puppet':
    ensure => running,
    enable => true,
  }

}
