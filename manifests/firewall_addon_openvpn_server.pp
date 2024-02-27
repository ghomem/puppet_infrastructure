### Purpose ########
# This class provides necessary firewall configurations for openvpn servers

### Warnings
# client isolation feature is still to be correctly implemented: since its not a need right now, it defaults to isolation

class puppet_infrastructure::firewall_addon_openvpn_server (

    $lan_bridge_iface ='br0',
    $wan_iface,
    Boolean $client_isolation = true,

){

    # specific firewall rules to comunication between bridge interface and the exterior
    #
    firewall { '202 allow flow from br0 exterior':      chain => 'FORWARD', iniface => $lan_bridge_iface, outiface => $wan_iface,        proto => 'all', action => 'accept' }
    firewall { '203 allow flow from exterior into br0': chain => 'FORWARD', iniface => $wan_iface,        outiface => $lan_bridge_iface, proto => 'all', action => 'accept', state => ['RELATED', 'ESTABLISHED'], }
    firewall { '204 allow flow loopback on br0':        chain => 'FORWARD', iniface => $lan_bridge_iface, outiface => $lan_bridge_iface, proto => 'all', action => 'accept' }

    firewall {'205 performing nat': table => 'nat', chain => 'POSTROUTING', outiface => $wan_iface, proto => 'all', jump => 'MASQUERADE' }

    # this is not directly related to firewall but might be a good place for activating
    # ipv4 forwarding between the server network interfaces
    sysctl   { 'net.ipv4.ip_forward': value => '1'  }
}
