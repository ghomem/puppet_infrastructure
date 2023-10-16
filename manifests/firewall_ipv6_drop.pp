### Purpose ########
# This class provides an add on to firewall_secure that DROPs all IPv6 traffic

### Dependencies ###
#  modules: puppetlabs-firewall
class puppet_infrastructure::firewall_ipv6_drop {

  firewall { '600 Drop ALL IPv6 - INPUT':
    chain    => 'INPUT',
    proto    => 'all',
    action   => drop,
    provider => 'ip6tables',
  }
  firewall { '601 Drop ALL IPv6 - FORWARD':
    chain    => 'FORWARD',
    proto    => 'all',
    action   => drop,
    provider => 'ip6tables',
  }
}
