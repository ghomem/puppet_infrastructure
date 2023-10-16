class puppet_infrastructure::openvpn_domain (
  String $join_user,
  String $join_password,
  String $domain_hostname,
  String $domain_netbios_name,
  String $domain_tld,
  String $winbind_separator,
  Array[String] $groups,
){

  $dependencies       = ['samba','winbind','krb5-user','libnss-winbind','libpam-winbind','cifs-utils','ntpdate']
  $domain_script_path = '/root'

  $prefixed_groups        = $groups.map | $group | { "${domain_netbios_name}${winbind_separator}${group}" }
  $comma_separated_groups = join($prefixed_groups, ',')

  package { $dependencies:
    ensure => 'installed',
    provider => 'apt',
  }

  file { '/etc/samba/smb.conf':
    ensure  => 'file',
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => template('puppet_infrastructure/openvpn/smb.conf.erb'),
    require => Package[$dependencies],
  }

  file { '/etc/security/pam_winbind.conf':
    ensure  => 'file',
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => template('puppet_infrastructure/openvpn/pam_winbind.conf.erb'),
    require => Package[$dependencies],
  }

  file { '/etc/krb5.conf':
    ensure  => 'file',
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => template('puppet_infrastructure/openvpn/krb5.conf.erb'),
    require => Package[$dependencies],
  }

  file { '/etc/nsswitch.conf':
    ensure  => 'file',
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    source  => 'puppet:///modules/puppet_infrastructure/openvpn/nsswitch.conf',
    require => Package[$dependencies],
  }

  file { '/etc/pam.d/openvpn':
    ensure  => 'file',
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    source  => 'puppet:///modules/puppet_infrastructure/openvpn/openvpn_pam',
    require => Package[$dependencies],
  }

  file { '/etc/pam.d':
    ensure  => 'directory',
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    require => File['/etc/pam.d/openvpn'],
  }

  file { "${domain_script_path}/join-domain.sh":
    ensure  => 'file',
    mode    => '0774',
    owner   => 'root',
    group   => 'root',
    content => template('puppet_infrastructure/openvpn/join-domain.sh.erb'),
    require => Package[$dependencies],
  }

  # This script is only executed if the node has not yet joined a domain
  # To check this we verify the presence of the join domain user and only execute the script if it is not present
  exec { 'join domain':
    command => "${domain_script_path}/join-domain.sh",
    unless  => "id ${join_user}@${domain_netbios_name}.${domain_tld}",
    path    => '/usr/bin:/usr/sbin',
    require => File['/etc/samba/smb.conf','/etc/krb5.conf','/etc/pam.d/openvpn',"${domain_script_path}/join-domain.sh",'/etc/nsswitch.conf','/etc/security/pam_winbind.conf'],
  }
}

