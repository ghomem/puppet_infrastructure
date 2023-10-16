# server with SSH available based on a whitelist, and HTTP ports based on a whitelist
node 'basic-secure04' {

    # FIXME: please edit with the IPs you want to whitelist for ssh
    $ssh_ip_whitelist = [ 'A.B.C.D' ]

    class {'puppet_infrastructure::node_base':
        ssh_strict              => true,
        ssh_acl                 => $ssh_ip_whitelist,
    }

    include passwd_common

    # IPs that can access the HTTP ports
    # FIXME: please edit
    $web_whitelist = [ 'A.B.C.D' ]

    $web_whitelist.each |String $ip| {
      firewall { "1000 accept http  $ip whitelist": proto => 'tcp', dport => 80 , action => 'accept', source => $ip }
      firewall { "1001 accept https $ip whitelist": proto => 'tcp', dport => 443, action => 'accept', source => $ip }
    }

}
