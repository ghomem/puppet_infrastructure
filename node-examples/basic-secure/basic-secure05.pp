node 'basic-secure05' {

    # FIXME: please edit with the IPs you want to whitelist for ssh
    $ssh_ip_whitelist = [ 'A.B.C.D' ]

    class {'puppet_infrastructure::node_base':
        ssh_strict              => true,
        ssh_acl                 => $ssh_ip_whitelist,
        ssh_port                => 4242,
        password_authentication => true,
    }

    include passwd_common
}
