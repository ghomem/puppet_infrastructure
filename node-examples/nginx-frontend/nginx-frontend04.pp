node 'nginx-frontend04' {

  # NGINX Frontend and Static Server with same SSL

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

  # Hello world index.html
  file { '/var/www/html/index.html':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "<html><head></head><body><h1>Hello World - ${trusted['certname']}<h1></body></html>",
    require => Class[ 'puppet_infrastructure::nginx_base' ],
  }

  # SSL certificate
  puppet_infrastructure::ssl_nginx_domain { 'star.puppetdemo.lan':
    sslprefix => 'star.puppetdemo.lan',
  }

  # Provide the files subdomain with static content
  puppet_infrastructure::nginx_static_domain { 'puppetdemo.lan':
    domain            => 'files.nginx-frontend04.puppetdemo.lan',
    www_root          => '/var/www/html',
    ssl               => true,
    static_sslprefix  => 'star.puppetdemo.lan',
    manage_ssl        => false,
  }

  class {'puppet_infrastructure::nginx_frontend':
    domain                  => 'puppetdemo.lan',
    frontend_sslprefix      => 'star.puppetdemo.lan',
    backend_hosts_and_ports => ['127.0.0.1:8000', ],
    backend_protocol        => 'http',
    manage_ssl              => false,
  }

  # Allow HTTP/HTTPS connections
  include puppet_infrastructure::firewall_addon_web

}
