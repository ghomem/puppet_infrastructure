node 'nginx-static02' {

  # Static HTTP server with defined type puppet_infrastructure::nginx_static_domain
  # Acess by IP configurable, see 'redirect_default' below

  include puppet_infrastructure::node_base
  include passwd_common
  include puppet_infrastructure::nginx_base

  # Hello world index.html
  file { '/var/www/html/index.html':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "<html><head></head><body><h1>Hello World - ${trusted['certname']}<h1></body></html>",
    require => Class[ 'puppet_infrastructure::nginx_base' ],
  }
 
  puppet_infrastructure::nginx_static_domain { 'nginx-static02.puppetdemo.lan':
    domain                 => 'nginx-static02.puppetdemo.lan',
    www_root               => '/var/www/html',
    server_default_create  => true,
    # By default this class creates an HTTP server and a default server
    # that returns 404 when the website is accessed by the IP.
    # If you want the website to be accessible by IP you can uncomment
    # the below to set 'redirect_default' to 'true'
    #redirect_default       => true,
  }

  # open HTTP ports to the Internet
  include puppet_infrastructure::firewall_addon_web

}
