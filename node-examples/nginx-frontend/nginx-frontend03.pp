node 'nginx-frontend03' {

  # This example has 1 domain, puppetdemo.lan with 2 subdomains, mail.puppetdemolan and chat.puppetdemo.lan, and 2 other domains, puppetdemo.co.uk and puppetdemo.net.

  # To have the domains used in this example you can add these lines to your /etc/hosts
  # <IP_of_this_machine>  puppetdemo.lan
  # <IP_of_this_machine>  mail.puppetdemo.lan
  # <IP_of_this_machine>  chat.puppetdemo.lan
  # <IP_of_this_machine>  puppetdemo.net
  # <IP_of_this_machine>  puppetdemo.co.uk
  # <IP_of_this_machine>  www.puppetdemo.co.uk

  # Basic desirable configuration for a generic Ubuntu node
  include puppet_infrastructure::node_base
  include passwd_common
  # Install nginx and perform configurations common to all servers
  include puppet_infrastructure::nginx_base
  # Open ports for http and https
  firewall { '200 nginx http': proto => 'tcp', dport => 80, action => 'accept', }
  firewall { '210 nginx https': proto => 'tcp', dport => 443, action => 'accept', }

  # Backends to simulate applications
  puppet_infrastructure::hello_world_flask {'main':
    ip_address  => '127.0.0.1',
    port        => 8000,
    uninstall   => false,
    welcome_msg => 'This is our main application @ puppetdemo.lan',
  }
  puppet_infrastructure::hello_world_flask {'mail':
    ip_address  => '127.0.0.1',
    port        => 8001,
    uninstall   => false,
    welcome_msg => 'This is our mail application @ mail.puppetdemo.lan',
  }
  puppet_infrastructure::hello_world_flask {'chat':
    ip_address  => '127.0.0.1',
    port        => 8002,
    uninstall   => false,
    welcome_msg => 'This is our chat restricted by IP @ chat.puppetdemo.lan',
  }
  puppet_infrastructure::hello_world_flask {'puppetdemo.co.uk':
    ip_address  => '127.0.0.1',
    port        => 8010,
    uninstall   => false,
    welcome_msg => 'This is our application @ puppetdemo.co.uk',
  }
  puppet_infrastructure::hello_world_flask {'puppetdemo.net':
    ip_address  => '127.0.0.1',
    port        => 8020,
    uninstall   => false,
    welcome_msg => 'This is our application @ puppetdemo.net',
  }


  # This class creates these servers:
  # - http server that redirects to https
  # - http_www server that redirects to https_www
  # - default server that redirects to https_www when accessed by IP
  # - http monitoring server
  # - main https server that serves https requests with and without www
  # This class also prevents redirects to external URLs. Since the nginx_frontend class manages ssl by default, it expects the ssl certificates and private key to be installed.
  # In this example those certificates should be multidomain and include mail.example.com and chat.example.com because the defined types for mail.example.com and chat.example.com (the 2 examples below this one) don't manage ssl.
  class { 'puppet_infrastructure::nginx_frontend':
    domain                       => 'puppetdemo.lan',
    frontend_sslprefix           => 'star.puppetdemo.lan',
    backend_hosts_and_ports      => ['127.0.0.1:8000', ],
    backend_protocol             => 'http',
    redirects_external_prevented => true,
    redirect_default             => true,
    server_monitoring_create     => true,
  }

  # This defined type creates these servers:
  # - http server that redirects to https
  # - main https server that serves http requests without www
  # Doesn't manage ssl, should have a multidomain certificate in the class.
  puppet_infrastructure::nginx_frontend_domain { 'mail.puppetdemo.lan':
    domain                                => 'mail.puppetdemo.lan',
    frontend_sslprefix                    => 'star.puppetdemo.lan',
    backend_hosts_and_ports               => ['127.0.0.1:8001', ],
    backend_protocol                      => 'http',
    redirect_http_www_to_https_www_create => false,
    server_https_www_create               => false,
  }

  # This defined type creates these servers:
  # - http server that redirects to https
  # - main https server that serves http requests without www
  # The servers only allow access to clients with IPs between 192.168.1.10 and 192.168.1.50
  # Doesn't manage ssl, should have a multidomain certificate in the class.
  puppet_infrastructure::nginx_frontend_domain { 'chat.puppetdemo.lan':
    domain                                => 'chat.puppetdemo.lan',
    frontend_sslprefix                    => 'star.puppetdemo.lan',
    backend_hosts_and_ports               => ['127.0.0.1:8002', ],
    backend_protocol                      => 'http',
    redirect_http_www_to_https_www_create => false,
    server_https_www_create               => false,
    ip_whitelist                          => [
      #'10.103.21.1/32',
      '10.103.21.0/24',
    ],
  }

  # This defined type creates these servers for a different domain:
  # - http server that redirects to https with www
  # - http www server that redirects to https with www
  # - https server that redirects to https with www
  # - main https server that serves http requests with www
  # It also manages its own ssl certificates and key, they are expected to be found at /etc/puppetlabs/puppet/extra_files/ssl/
  puppet_infrastructure::nginx_frontend_domain { 'puppetdemo.co.uk':
    domain                  => 'puppetdemo.co.uk',
    frontend_sslprefix      => 'puppetdemo.co.uk',
    backend_hosts_and_ports => ['127.0.0.1:8010', ],
    backend_protocol        => 'http',
    decorate_naked          => true,
    manage_ssl              => true,
  }

  # This defined type creates these servers for a different domain:
  # - http server that redirects to https without www
  # - http www server that redirects to https www
  # - main https server that serves http requests with and without www
  # It also manages its own ssl certificates and key, they are expected to be found at /etc/puppetlabs/puppet/extra_files/ssl/
  puppet_infrastructure::nginx_frontend_domain { 'puppetdemo.net':
    domain                                => 'puppetdemo.net',
    frontend_sslprefix                    => 'puppetdemo.net',
    backend_hosts_and_ports               => ['127.0.0.1:8020', ],
    backend_protocol                      => 'http',
    redirect_http_www_to_https_www_create => true,
    server_https_www_create               => true,
    manage_ssl                            => true,
  }

}
