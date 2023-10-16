### Purpose ########
# This class provides COMPLEMENTARY firewall configurations for web traffic
### Warnings #######
# Do not forget to do the main firewall configuration,
# either by including one of our base classes
# (puppet_infrastructure::firewall or puppet_infrastructure::firewall_secure)
# or trough some other alternative (e.g. bash scripts).
### Dependencies ###
#  modules: puppetlabs-firewall

class puppet_infrastructure::firewall_addon_web {

  # webserver specific firewall rules - simple case
  firewall { '200 accept http':  proto  => 'tcp', dport  => 80,  action => 'accept', }
  firewall { '201 accept https': proto  => 'tcp', dport  => 443, action => 'accept', }

}
