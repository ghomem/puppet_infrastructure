### Purpose ########
# This class configures a network interface with DHCP.
#
# It was originally created because the OpenVPN server class
# needs to manage interface lo and it has been found that
# once puppet starts managing one interface it has to manage
# all of them.

class puppet_infrastructure::network_dhcp ( $iface ) {

    package        { 'ifupdown-extra': ensure => 'installed', }
    network_config { $iface:           ensure => 'present', family  => 'inet', onboot => 'true', method => 'dhcp', hotplug => 'false' }

}
