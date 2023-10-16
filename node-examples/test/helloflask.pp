node 'helloflask' {

  include puppet_infrastructure::node_base
  include passwd_common

  puppet_infrastructure::hello_world_flask {'primary':
    ip_address  => '0.0.0.0',
    port        => 80,
    uninstall   => false,
    welcome_msg => 'This is our primary application',
  }

  puppet_infrastructure::hello_world_flask {'secondary':
    ip_address  => '0.0.0.0',
    port        => 8080,
    uninstall   => false,
    welcome_msg => 'This is our secondary application',
  }

  # open HTTP ports to the Internet
  include puppet_infrastructure::firewall_addon_web
  firewall { "1000 accept alt http": proto => 'tcp', dport => 8080 , action => 'accept' }

}
