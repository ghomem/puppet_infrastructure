### Purpose ########
# Configure OpenVPN connections on Desktop clients

## Warnings ##
# This class has only been tested on LD7 machines
# This configuration does not include setup of passwords

# nm stands for Network Manager
define puppet_infrastructure::openvpn_nm_connection(

    $connection_name = $title,
    $vpn_username,
    $local_username,
    $remote, # server name or IP address
    $cipher = 'AES-256-CBC',
    $ca_crt, # absolute path of file

){

    $openvpn_keys_subdir = 'openvpn/keys'

    exec {"Reload Network Manager Connections: ${title}":
        name        => '/usr/bin/nmcli con reload',
        refreshonly => true,
    }

    # generate some random uuid here
    # $uuid="7b9a2c18-c9e6-4b33-851e-2a8d2d2d7c05"
    $uuid = fqdn_rand_uuid($connection_name)

    file { "/etc/NetworkManager/system-connections/${connection_name}":
        mode    => '0600',
        owner   => 'root',
        group   => 'root',
        content => template('puppet_infrastructure/openvpn/connection_file.erb'),
        notify  => Exec["Reload Network Manager Connections: ${title}" ],
        require => File[$ca_crt],
    }

}

