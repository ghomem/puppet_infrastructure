### Purpose ########
# This class provides COMPLEMENTARY firewall configurations for hosting servers
### Warnings #######
# Do not forget to do the main firewall configuration,
# either by including one of our base classes
# (puppet_infrastructure::firewall or puppet_infrastructure::firewall_secure)
# or trough some other alternative (e.g. bash scripts).
### Dependencies ###
#  modules: puppetlabs-firewall

class puppet_infrastructure::firewall_addon_hosting {

  # override the default OUTPUT from the firewall class - can't touch this!
  firewallchain { 'OUTPUT:filter:IPv4':  ensure => present, purge => true, policy => drop }
  firewall { '149 OUTPUT ACCEPT RELATED ESTABLISHED': chain => 'OUTPUT', state => [ 'RELATED', 'ESTABLISHED'] , action => 'accept' }

  # this is customizable
  firewall { '150 OUTPUT DNS': chain => 'OUTPUT', proto => 'udp', dport => '53' ,  action => 'accept' }
  firewall { '151 OUTPUT NTP': chain => 'OUTPUT', proto => 'udp', dport => '123' , action => 'accept' }

}
