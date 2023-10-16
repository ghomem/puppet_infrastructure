node 'nginx-frontend02' {

  # Example for NGINX frontend with main website and secondary subdomains

  # To have the extra domains used in this example you can add these lines to your /etc/hosts
  # <IP_of_this_machine>  primary.nginx-frontend02.puppetdemo.lan
  # <IP_of_this_machine>  secondary.nginx-frontend02.puppetdemo.lan

  # Basic includes
  include puppet_infrastructure::node_base
  include passwd_common
  include puppet_infrastructure::nginx_base

  # Backend - flask application listening on 127.0.0.1:8000
  puppet_infrastructure::hello_world_flask {'main':
    ip_address  => '127.0.0.1',
    port        => 8000,
    uninstall   => false,
    welcome_msg => 'This is our main application',
  }

  # Backend - flask application listening on 127.0.0.1:8001
  puppet_infrastructure::hello_world_flask {'primary':
    ip_address  => '127.0.0.1',
    port        => 8001,
    uninstall   => false,
    welcome_msg => 'This is our primary application',
  }

  # Backend - flask another application listening on 127.0.0.1:8002
  puppet_infrastructure::hello_world_flask {'secondary':
    ip_address  => '127.0.0.1',
    port        => 8002,
    uninstall   => false,
    welcome_msg => 'This is our secondary application',
  }

  # Frontend for https://nginx-frontend02.puppetdemo.lan
  class { 'puppet_infrastructure::nginx_frontend':
    domain                  => 'nginx-frontend02.puppetdemo.lan',
    frontend_sslprefix      => 'star.puppetdemo.lan',
    backend_hosts_and_ports => ['127.0.0.1:8000', ],
    backend_protocol        => 'http',
  }

  # Frontend for https://primary.nginx-frontend02.puppetdemo.lan
  puppet_infrastructure::nginx_frontend_domain { 'primary.nginx-frontend02.puppetdemo.lan':
    domain                                => 'primary.nginx-frontend02.puppetdemo.lan',
    frontend_sslprefix                    => 'star.puppetdemo.lan',
    backend_hosts_and_ports               => ['127.0.0.1:8001', ],
    backend_protocol                      => 'http',
    manage_ssl                            => false,
    redirect_http_www_to_https_www_create => false,
    server_https_www_create               => false,
  }

  # Frontend for https://secondary.nginx-frontend02.puppetdemo.lan
  puppet_infrastructure::nginx_frontend_domain { 'secondary.nginx-frontend02.puppetdemo.lan':
    domain                                => 'secondary.nginx-frontend02.puppetdemo.lan',
    frontend_sslprefix                    => 'star.puppetdemo.lan',
    backend_hosts_and_ports               => ['127.0.0.1:8002', ],
    backend_protocol                      => 'http',
    manage_ssl                            => false,
    redirect_http_www_to_https_www_create => false,
    server_https_www_create               => false,
  }

  # Allow HTTP/HTTPS connections
  include puppet_infrastructure::firewall_addon_web

}
