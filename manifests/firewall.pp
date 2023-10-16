### Purpose ########
# This class provides a base firewall configuration that DROPs INPUT and FORWARD
# allowing OUTPUT and specific INPUTs for SSH and ICMP

### Dependencies ###
#  modules: puppetlabs-firewall

# IMPORTANT: consider using firewall_secure instead of this class

class puppet_infrastructure::firewall {
  Firewall {
    require => undef,
  }

  $localdir = lookup('filesystem::localdir')

  # Script that clears all firewall rules to be used only in exceptional cases (see issue 119)
  file { "${localdir}/bin/iptables-flush.sh":
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    source  => 'puppet:///modules/puppet_infrastructure/iptables/iptables-flush.sh',
    require => File[ "${localdir}/bin" ],
  }

  # Purge all firewall rules not managed by puppet
  resources { 'firewall': purge => true, }

  # Policies
  firewallchain { 'FORWARD:filter:IPv4': ensure => present, purge => true, policy => drop   }
  firewallchain { 'INPUT:filter:IPv4':   ensure => present, purge => true, policy => drop   }

  # Default firewall rules
  firewall { '000 accept all icmp':
    proto  => 'icmp',
    action => 'accept',
  }
  -> firewall { '001 accept all to lo interface':
    proto   => 'all',
    iniface => 'lo',
    action  => 'accept',
  }
  -> firewall { '002 reject local traffic not on loopback interface':
    iniface     => '! lo',
    proto       => 'all',
    destination => '127.0.0.1/8',
    action      => 'reject',
  }
  -> firewall { '003 accept related established rules':
    proto  => 'all',
    state  => ['RELATED', 'ESTABLISHED'],
    action => 'accept',
  }

  # accept SSH from all
  firewall { '100 accept ssh':
    proto  => 'tcp',
    dport  => 22,
    action => 'accept',
  }

}
