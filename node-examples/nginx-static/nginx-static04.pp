node 'nginx-static04' {

  # Static HTTPS server with defined type puppet_infrastructure::nginx_static_domain
  # and no HTTP -> HTTPS redirection
  # Acess by IP configurable, see 'redirect_default' below

  include puppet_infrastructure::node_base
  include passwd_common
  include puppet_infrastructure::nginx_base

  file { '/var/www':
    ensure => directory,
  }

  file { '/var/www/html':
    ensure => directory,
  }

  # Hello world index.html
  file { '/var/www/html/index.html':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "<html><head></head><body><h1>Hello World - ${trusted['certname']}<h1></body></html>",
    require => Class[ 'puppet_infrastructure::nginx_base' ],
  }
 
  puppet_infrastructure::nginx_static_domain { 'nginx-static04.puppetdemo.lan':
    domain                 => 'nginx-static04.puppetdemo.lan',
    www_root               => '/var/www/html',
    ssl                    => true,
    static_sslprefix       => 'star.puppetdemo.lan',
    manage_ssl             => true,
    server_default_create  => true,
    # By default this class creates an HTTP server and a default server
    # that returns 404 when the website is accessed by the IP.
    # If you want the website to be accessible by IP you can uncomment
    # the below to set 'redirect_default' to 'true'
    # Caveat: given that this nginx static server has ssl, as a side
    # effect of activating 'redirect_default' you will have HTTP -> HTTPS
    # redirection
    #redirect_default      => true,
  }

  # open HTTP ports to the Internet
  include puppet_infrastructure::firewall_addon_web

}
