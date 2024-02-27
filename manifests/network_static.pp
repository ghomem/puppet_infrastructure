### Purpose ########
# This class configures a network interface with static parameters.
#
# It was originally created because the OpenVPN server class
# needs to manage interface lo and it has been found that
# once puppet starts managing one interface it has to manage
# all of them.

class puppet_infrastructure::network_static ( $iface, $ipaddress, $gateway ) {

    package        { 'ifupdown-extra': ensure => 'installed', }
    network_config { $iface:           ensure => 'present', family  => 'inet',   onboot    => 'true', method => 'static',   ipaddress => $ipaddress, hotplug => 'false' }
    network_route  { 'default':        ensure => 'present', gateway => $gateway, interface => 'eth0', netmask => '0.0.0.0', network   => 'default' }

}
