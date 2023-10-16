### Purpose ########
# This class provides necessary firewall configurations for caching nameservers

class puppet_infrastructure::firewall_addon_caching_nameserver (

    $lan_iface,
    $port = '53',

){

    firewall { '1301 accept nameserver': proto => 'udp', iniface => $lan_iface, dport => $port, action => 'accept' }

}
