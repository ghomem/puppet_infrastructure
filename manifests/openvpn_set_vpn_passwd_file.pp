### Purpose ########
# Placement and configuration of a script that allows
# settup of multiple openvpn connections on LD7 machines

## Warnings ##
# This class has only been tested on LD7 machines

## Example ##
# the file_path should be the complete path, just like a File declaration
#
#
# Example of placement in our local bin dir
# puppet_infrastructure::openvpn_set_vpn_passwd_file { '/usr/local/AS/bin/set_vpn_passwd.sh':
#   vpn_list => ['VPN1', 'VPN2', 'VPN3']
# }
#

# this class is a define type because we might want
# to manage more than one group of vpn connections
define puppet_infrastructure::openvpn_set_vpn_passwd_file(

    # vpn_list is an array containing the name of the configured connections
    # vpn names should not have spaces
    Array $vpn_list = [],
    $file_owner = 'root',
    $file_path = $title
){

    file { $file_path:
        mode    => '0755',
        owner   => $file_owner,
        group   => $file_owner,
        content => template('puppet_infrastructure/openvpn/set_vpn_passwd.sh.erb'),
    }
}
