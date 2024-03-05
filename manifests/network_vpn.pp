### Purpose ########
# This class configures an OpenVPN server with user auth and
# and an internal caching nameserver for DNS resolution to be
# provided independently from the VPN client network.
#
# It expects OpenVPN SSL environment specific files at:
#
#   puppet://extra_files/openvpn/keys/server.crt
#   puppet://extra_files/openvpn/keys/server.key
#   puppet://extra_files/openvpn/keys/ca.crt
#   puppet://extra_files/openvpn/keys/dh2048.pem

class puppet_infrastructure::network_vpn (
  Boolean $client_isolation = true,
  $wan_iface                = 'eth0',
  $openvpn_lan_iface        = 'lo:0',
  $openvpn_bridge_iface     = 'br0',
  $openvpn_reneg_sec        = 3600,
  $openvpn_static_ip        = '192.168.101.1',
  $openvpn_netmask          = '255.255.255.0',
  $openvpn_network          = '192.168.101.0',
  $openvpn_broadcast        = '192.168.101.255',
  $openvpn_pool_start       = '192.168.101.101',
  $openvpn_pool_end         = '192.168.101.200',
  $openvpn_cipher           = 'AES-256-CBC',
  $openvpn_client_dns       = $openvpn_static_ip,
) {

    # Caching nameserver for the VPN

    class { 'puppet_infrastructure::caching_nameserver':
        allowed_networks => ["${openvpn_network}/24"]
    }

    class { 'puppet_infrastructure::firewall_addon_caching_nameserver':
        lan_iface => $openvpn_bridge_iface
    }

    # OpenVPN specific internal firewall rules

    class { 'puppet_infrastructure::firewall_addon_openvpn_server':
        wan_iface        => $wan_iface,
        lan_bridge_iface => $openvpn_bridge_iface,
    }

    # expects OpenVPN SSL files at: puppet://extra_files/openvpn/keys
    class { 'puppet_infrastructure::openvpn_server':
        lan_static_ip    => $openvpn_static_ip,
        lan_netmask      => $openvpn_netmask,
        lan_network      => $openvpn_network,
        lan_broadcast    => $openvpn_broadcast,
        vpn_pool_start   => $openvpn_pool_start,
        vpn_pool_end     => $openvpn_pool_end,
        lan_iface        => $openvpn_lan_iface,
        lan_bridge_iface => $openvpn_bridge_iface,
        push_dns_server  => $openvpn_client_dns,
        cipher           => $openvpn_cipher,
        reneg_sec        => $openvpn_reneg_sec,
        client_isolation => $client_isolation,
    }

}
