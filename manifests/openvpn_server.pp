### Purpose ########
# Configure a server running ubuntu as a OpenVPN server
# This configuration is based on our gateway's configuration

## Warnings ##
# This class as only been tested on Ubuntu 16.04

class puppet_infrastructure::openvpn_server (

    $lan_static_ip,
    $lan_netmask,
    $lan_network,
    $lan_broadcast,
    $vpn_pool_start,
    $vpn_pool_end,
    $lan_iface                = 'lo:0',
    $lan_bridge_iface         = 'br0',
    $push_dns_server          = '8.8.8.8',
    $cipher                   = 'AES-256-CBC',
    # see https://github.com/voxpupuli/puppet-openvpn/blob/master/manifests/server.pp#LC17
    # @param local
    # the local parameter tells openvpn which interface to bind to
    $local                    = $::networking['ip'],
    $local_interface          = $::networking['primary'],
    Boolean $client_isolation = true,
    # Defines whether the primary interface should be forcefully managed by ifupdown
    # Only set to true on systems with Netplan
    Boolean $force_ifupdown   = false,
    $reneg_sec                = 3600, # amount of seconds between each session key renegotiation
    $compression              = 'comp-lzo' # To disable compression this value needs to be set to 'none'

){
    $major_release = $facts['os']['release']['major']

    package { [ 'ifupdown', 'bridge-utils']: ensure => present }

    # enabling the service, following these instruction
    # https://askubuntu.com/questions/1031709/ubuntu-18-04-switch-back-to-etc-network-interfaces
    service { 'networking':
        enable => true
    }

    # convert client isolation variable
    # into the corresponding system configuration value
    $proxy_arp = Numeric(!$client_isolation)

    $openvpn_keys_dir = '/etc/openvpn/keys'
    $openvpn_keys_subdir = 'openvpn/keys'

    if $force_ifupdown {
        # On some systems, interfaces are internally managed by Netplan and errors occur when restarting
        # the networking service, when setting a static IP, as it uses ifupdown
        # To ensure that the Puppet run executes without errors we must force the primary interface to be managed
        # by ifupdown instead of Netplan
        exec { 'force ifupdown':
            command     => "ifdown --force ${local_interface} lo && ifup -a",
            refreshonly => true,
            path        => '/usr/sbin',
            require     => Package['bridge-utils'],
            subscribe   => Network_config['lo', $lan_iface, $local_interface, $lan_bridge_iface],
        }

        # interfaces definition
        exec { 'restart network':
            command     => '/bin/bash -c "systemctl restart networking"',
            refreshonly => true,
            require     => Exec['force ifupdown'],
            subscribe   => Network_config['lo', $lan_iface, $local_interface, $lan_bridge_iface],
        }

    } else {
        # interfaces definition
        exec { 'restart network':
            command     => '/bin/bash -c "systemctl restart networking"',
            refreshonly => true,
            require     => Package['bridge-utils'],
            subscribe   => Network_config['lo', $lan_iface, $local_interface, $lan_bridge_iface],
        }
    }

    # making sure loopback interface is present
    network_config { 'lo':
        ensure  => 'present',
        family  => 'inet',
        onboot  => true,
        method  => 'loopback',
        hotplug => false,
    }

    # LAN interface to bridge
    network_config { $lan_iface :
        ensure  => 'present',
        family  => 'inet',
        onboot  => true,
        method  => 'loopback',
        hotplug => false,
    }

    # declaration of the bridge
    network_config { $lan_bridge_iface :
        ensure    => 'present',
        family    => 'inet',
        onboot    => true,
        hotplug   => false,
        method    => 'static',
        ipaddress => $lan_static_ip,
        netmask   => $lan_netmask,
        options   =>  {
                        network         => $lan_network,
                        broadcast       => $lan_broadcast,
                        dns-nameservers => $push_dns_server,
                        bridge_ports    => $lan_iface,
                        bridge_stp      => 'off'
                      },
    }

    service { 'openvpn-server@puppet_infrastructure':
        ensure   => 'running',
        enable   => 'true',
        provider => 'systemd',
    }

    # security files for openvpn server 
    file {"${openvpn_keys_dir}/ca.crt":
        mode   => '0644',
        owner  => 'root',
        group  => 'root',
        source => "puppet:///extra_files/${openvpn_keys_subdir}/ca.crt",
        notify => Service['openvpn-server@puppet_infrastructure'],
    }

    file {"${openvpn_keys_dir}/dh2048.pem":
        mode   => '0644',
        owner  => 'root',
        group  => 'root',
        source => "puppet:///extra_files/${openvpn_keys_subdir}/dh2048.pem",
        notify => Service['openvpn-server@puppet_infrastructure'],
    }

    file {"${openvpn_keys_dir}/server.crt":
        mode   => '0644',
        owner  => 'root',
        group  => 'root',
        source => "puppet:///extra_files/${openvpn_keys_subdir}/server.crt",
        notify => Service['openvpn-server@puppet_infrastructure'],
    }

    file {"${openvpn_keys_dir}/server.key":
        mode   => '0644',
        owner  => 'root',
        group  => 'root',
        source => "puppet:///extra_files/${openvpn_keys_subdir}/server.key",
        notify => Service['openvpn-server@puppet_infrastructure'],
    }

    #Set the default path of the config file
    class { 'openvpn':
      server_directory => '/etc/openvpn/server',
    }

    # configuration of the openvpn server itself
    openvpn::server { 'puppet_infrastructure':
        verb                     => '3',
        user                     => 'nobody',
        proto                    => 'udp',
        compression              => $compression,
        dev                      => 'tap0',
        username_as_common_name  => true,
        pam                      => true,
        persist_key              => true,
        persist_tun              => true,
        push                     => ['redirect-gateway bypass-dhcp bypass-dns', "dhcp-option DNS ${push_dns_server}"],
        server_bridge            => "${lan_static_ip} ${lan_netmask} ${vpn_pool_start} ${vpn_pool_end}",
        up                       => "/etc/openvpn/openvpn-up.sh ${lan_bridge_iface} ${lan_iface} tap0",
        crl_verify               => false,
        extca_enabled            => true,
        cipher                   => $cipher,
        extca_ca_cert_file       => "${openvpn_keys_dir}/ca.crt",
        extca_server_cert_file   => "${openvpn_keys_dir}/server.crt",
        extca_server_key_file    => "${openvpn_keys_dir}/server.key",
        extca_dh_file            => "${openvpn_keys_dir}/dh2048.pem",
        tls_auth                 => false,
        require                  => [ File["${openvpn_keys_dir}/ca.crt"], File["${openvpn_keys_dir}/dh2048.pem"], File["${openvpn_keys_dir}/server.crt"], File["${openvpn_keys_dir}/server.key"] ],
        local                    => $local,
        custom_options           => { 'reneg-sec' => $reneg_sec, 'verify-client-cert' => 'none' },
        notify                   => Service['openvpn-server@puppet_infrastructure'],
    }

    file { '/usr/lib/openvpn':
        ensure => directory,
        mode   => '0744',
        owner  => 'root',
        group  => 'root',
    }

    file { '/usr/lib/openvpn/openvpn-plugin-auth-pam.so':
        ensure  => link,
        target  => '/usr/lib/x86_64-linux-gnu/openvpn/plugins/openvpn-plugin-auth-pam.so',
        require => [Package['openvpn'], File['/usr/lib/openvpn']],
    }

    file { '/etc/openvpn/openvpn-up.sh':
        mode    => '0755',
        owner   => 'root',
        group   => 'root',
        source  => 'puppet:///modules/puppet_infrastructure/openvpn/openvpn-up.sh',
        require => Package[ 'openvpn' ],
        notify  => Service['openvpn'],
    }

    sysctl  { 'net.ipv4.conf.br0.proxy_arp_pvlan': value => $proxy_arp  }

}
