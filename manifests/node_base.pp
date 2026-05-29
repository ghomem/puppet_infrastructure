### Purpose ########
# This class provides basic desirable properties of a generic Ubuntu node
class puppet_infrastructure::node_base ( Boolean $password_authentication                  = false,
                                  Boolean $ssh_strict                               = false,
                                  Array $ssh_acl                                    = [],
                                  Boolean $customize_syslog_mode                    = false,
                                  String $syslog_mode                               = 'u=rw,g=r,o=',
                                  Boolean $firewall_secure_extra                    = false,
                                  Boolean $anti_ddos                                = false,
                                  String $ddos_limit                                = '100',
                                  String $ddos_limit_per_time_unit                  = '60',
                                  String $ddos_limit_time_unit                      = 'sec',
                                  $service_list                                     = [],
                                  Boolean $ip_filter                                = false,
                                  String $country_whitelist                         = '',
                                  Array $ip_whitelist                               = [],
                                  Array $ip_blacklist                               = [],
                                  Boolean $internal_forward                         = false,
                                  $internal_forward_list                            = [],
                                  String $forward_iniface                           = '',
                                  String $good_mark                                 = '0x413',
                                  String $bad_mark                                  = '0x406',
                                  Boolean $firewall_strict_purge                    = true,
                                  Array[String] $firewall_ignore_patterns           = [],
                                  $ssh_port                                         = 22,
                                  Boolean $ssh_allow_root_login                     = false,
                                  Boolean $run_puppet_on_boot                       = false,
                                  Array[String] $apt_surface_list                   = [], # if empty it will default to a builtin list
                                  Array[String] $host_keys                          = ['/etc/ssh/ssh_host_ed25519_key','/etc/ssh/ssh_host_ecdsa_key','/etc/ssh/ssh_host_rsa_key'],
                                  String $kex_algorithm                             = 'diffie-hellman-group-exchange-sha256',
                                  String $ciphers                                   = 'aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr',
                                  String $macs                                      = 'hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256',
                                  Boolean $custom_ntp                               = false,
                                  Array[String] $ntp_servers                        = [],
                                  # Server PPAs
                                  Enum['production', 'staging', 'none'] $server_ppa = 'none',
                                  # Relevant updates method
                                  # 0 - no relevant updates support
                                  # 1 - reseved for an old method, no longer supported
                                  # 2 - method based on analysis of the oval data provided by Ubuntu, see: https://ubuntu.com/security/oval
                                  Integer $relevant_updates_method                  = 2,
                                  # Select if we want to take into account kernel updates or not
                                  # This option only works if we use the relevant updates method 2 above
                                  Boolean $relevant_updates_no_kernel               = false,
                                  #This is an optional list of IP adresses that will be set as DNS servers for the client
                                  Array[String] $nameservers                        = [],
                                  Boolean $filesystem_security                      = true,
) {

  $os_family = $facts['os']['family']

  class { 'puppet_infrastructure::packages_base':
    unattended_upgrades => false,
  }
  class { 'puppet_infrastructure::sysmon_base':
    require => Class['puppet_infrastructure::packages_base']
  }

  class { 'puppet_infrastructure::ssh_secure': password_authentication => $password_authentication, root_login => $ssh_allow_root_login, port => $ssh_port, host_keys => $host_keys, kex_algorithm => $kex_algorithm, ciphers => $ciphers, macs => $macs}

  if $os_family == 'RedHat' {

    # Stop and disable the firewalld service to prevent it from starting at boot
    service { 'firewalld':
      ensure => 'stopped',
      enable => false,
    }

    # Mask the firewalld service to prevent manual start
    exec { 'mask firewalld':
      command => '/bin/systemctl mask firewalld',
      unless  => '/bin/systemctl is-enabled firewalld | /bin/grep masked',
      require => Service['firewalld'],
    }

  }


  if ($firewall_secure_extra){
    class { 'puppet_infrastructure::firewall_secure_extra':
      strict                   => $ssh_strict,
      acl                      => $ssh_acl,
      anti_ddos                => $anti_ddos,
      service_list             => $service_list,
      ip_filter                => $ip_filter,
      country_whitelist        => $country_whitelist,
      ddos_limit               => $ddos_limit,
      ddos_limit_per_time_unit => $ddos_limit_per_time_unit,
      ddos_limit_time_unit     => $ddos_limit_time_unit,
      ip_whitelist             => $ip_whitelist,
      ip_blacklist             => $ip_blacklist,
      internal_forward         => $internal_forward,
      internal_forward_list    => $internal_forward_list,
      forward_iniface          => $forward_iniface,
      good_mark                => $good_mark,
      bad_mark                 => $bad_mark,
      ssh_port                 => $ssh_port
    }
  }
  else {
    class { 'puppet_infrastructure::firewall_secure': strict => $ssh_strict, acl => $ssh_acl, strict_purge => $firewall_strict_purge, ignore_patterns => $firewall_ignore_patterns, ssh_port => $ssh_port }
  }
  
  include puppet_infrastructure::firewall_ipv6_drop
  class { 'puppet_infrastructure::filesystem_base':
    customize_syslog_mode => $customize_syslog_mode,
    syslog_mode           => $syslog_mode,
  }

  if $os_family == 'RedHat' {
    include puppet_infrastructure::filesystem_yum
  } else {
    include puppet_infrastructure::filesystem_lib64
    class { 'puppet_infrastructure::filesystem_apt':
      apt_surface_list           => $apt_surface_list,
      server_mode                => true,
      relevant_updates_method    => $relevant_updates_method,
      relevant_updates_no_kernel => $relevant_updates_no_kernel,
    }
  }

  # per node definition overrides default definition
  $restricted_cmds  = lookup( [ "${clientcert}::filesystem::restricted_cmds",  'filesystem::restricted_cmds'  ] )
  $restricted_mode  = lookup( [ "${clientcert}::filesystem::restricted_mode",  'filesystem::restricted_mode'  ] )
  if $os_family == 'RedHat' {
    $restricted_group = lookup( [ "${clientcert}::filesystem::restricted_group", 'filesystem::restricted_group_rhel' ] )
  } else {
    $restricted_group = lookup( [ "${clientcert}::filesystem::restricted_group", 'filesystem::restricted_group_ubuntu' ] )
  }

  if $filesystem_security {
    puppet_infrastructure::filesystem_sec { 'filesystem_sec': restricted_cmds => $restricted_cmds, restricted_group => $restricted_group , restricted_mode => $restricted_mode }
  }

  if $facts['os']['family'] == 'RedHat' {
    # For RHEL-based systems, use Chrony
    if $custom_ntp {
      if $ntp_servers.empty {
        fail('$ntp_servers must be passed if setting custom NTP.')
      }

      class { 'chrony':
        servers => $ntp_servers,
      }
    } else {
      include ::chrony
    }
  } else {
    # For non-RHEL systems, use NTP
    if $custom_ntp {
      if $ntp_servers.empty {
        fail('$ntp_servers must be passed if setting custom NTP.')
      }

      class { 'ntp':
        servers => $ntp_servers,
      }
    } else {
      include ::ntp
    }
  }

  if ($run_puppet_on_boot){
    include puppet_infrastructure::puppet_boot_run
  }

  class { 'puppet_infrastructure::dns_client':
    nameservers => $nameservers,
  }

}
