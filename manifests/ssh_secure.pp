### Purpose ########
# This class provides sshd management class with improved security settings

class puppet_infrastructure::ssh_secure (
  Integer $client_alive_interval   = 14400, 
  Boolean $password_authentication = false, 
  Boolean $root_login              = false, 
  Integer $port                    = 22, 
  Array[String] $host_keys         = ['/etc/ssh/ssh_host_ed25519_key','/etc/ssh/ssh_host_ecdsa_key','/etc/ssh/ssh_host_rsa_key'],
  String $kex_algorithm            = 'diffie-hellman-group-exchange-sha256',
  String $ciphers                  = 'aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr',
  String $macs                     = 'hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256',
) {

  case $::osfamily {
      'RedHat': {
        $ssh_service = 'sshd'
        $admin_group = 'wheel'
      }
      default: {
        $ssh_service = 'ssh'
        $admin_group = 'sudo'
      }
  }

  # our own modified moduli file
  file { '/etc/ssh/moduli' :
  owner  => root,
  group  => root,
  mode   => '0644',
  source => 'puppet:///modules/puppet_infrastructure/ssh/moduli',
  notify => Service[ $ssh_service ]
  }

  # this group is used for non-sudoers that need ssh in
  group {'ssh_in':
    ensure => present,
  }
  # and gets concatenated with any other group from the node
  # https://bitbucket.org/asolidodev/puppet_infrastructure/issues/20
  $othergroups = join([lookup ( "${clientcert}::ssh::othergroups", String, 'first', '' ), ' ssh_in'])

  if ( $password_authentication == false) {
    $my_password_authentication = 'no'
  } else {
    $my_password_authentication = 'yes'
  }

  if ( $root_login == false) {
    $my_root_login = 'no'
  } else {
    $my_root_login = 'yes'
  }

  class { 'ssh::server':
    options => {
      'Protocol'                => '2' ,
      'HostKey'                 => $host_keys,
      'KexAlgorithms'           => $kex_algorithm,
      'Ciphers'                 => $ciphers,
      'MACs'                    => $macs,
      'HostbasedAuthentication' => 'no' ,
      'IgnoreRhosts'            => 'yes' ,
      'LoginGraceTime'          => '120' ,
      'LogLevel'                => 'INFO' ,
      'PasswordAuthentication'  => $my_password_authentication ,
      'PermitEmptyPasswords'    => 'no' ,
      'PermitRootLogin'         => $my_root_login ,
      'Port'                    => "${port}" ,
      'PrintLastLog'            => 'yes' ,
      'PubkeyAuthentication'    => 'yes' ,
      'StrictModes'             => 'yes' ,
      'SyslogFacility'          => 'AUTH' ,
      'TCPKeepAlive'            => 'yes' ,
      'ClientAliveCountMax'     => '0',
      'ClientAliveInterval'     => $client_alive_interval,
      'UsePrivilegeSeparation'  => 'yes' ,
      'X11DisplayOffset'        => '10' ,
      'AllowGroups'             => "${admin_group} naemon ${othergroups}" ,
    },
  }

}
