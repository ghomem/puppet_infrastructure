node 'nginx-static07' {

  # In order to have the domains used in this node example you may add these lines to your /etc/hosts:
  # <IP_of_this_machine> puppetdemo.test
  # <IP_of_this_machine> www.puppetdemo.test
  # <IP_of_this_machine> files.puppetdemo.test
  # <IP_of_this_machine> basicfiles.puppetdemo.test
  # <IP_of_this_machine> listedfiles.puppetdemo.test
  # <IP_of_this_machine> internalfiles.puppetdemo.test

  # Basic desirable configuration for a generic Ubuntu node
  include puppet_infrastructure::node_base
  include passwd_common
  # Install nginx and perform configurations common to all servers
  include puppet_infrastructure::nginx_base
  # Open ports for http and https
  firewall { '200 nginx http': proto => 'tcp', dport => 80, action => 'accept', }
  firewall { '210 nginx https': proto => 'tcp', dport => 443, action => 'accept', }
  # Set main domain
  $domain = 'puppetdemo.test'

  ####################################### Example files and directories ###########################################

  file { '/var/www':
    ensure => directory,
  }

  file { '/var/www/html':
    ensure => directory,
  }

  # Main directory for domain puppetdemo.test
  file { "/var/www/html/${domain}/":
    ensure  => 'directory',
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    require => Class[ 'puppet_infrastructure::nginx_base' ],
  }

  # Main static site
  file { "/var/www/html/${domain}/site":
    ensure  => 'directory',
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    require => File[ "/var/www/html/${domain}" ],
  }
  file { "/var/www/html/${domain}/site/index.html":
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "<html><head></head><body><h1>This is our main static site @ puppetdemo.test<h1></body></html>",
    require => File[ "/var/www/html/${domain}/site" ],
  }

  # Files for files.puppetdemo.test
  file { "/var/www/html/${domain}/files":
    ensure  => 'directory',
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    require => File[ "/var/www/html/${domain}" ],
  }
  file { "/var/www/html/${domain}/files/file.txt":
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "This is a sample file @ files.puppetdemo.test",
    require => File[ "/var/www/html/${domain}/files" ],
  }

  # Files for basicfiles.puppetdemo.test
  file { "/var/www/html/${domain}/basicfiles":
    ensure  => 'directory',
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    require => File[ "/var/www/html/${domain}" ],
  }
  file { "/var/www/html/${domain}/basicfiles/basicfile.txt":
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "This is a sample basic file @ basicfiles.puppetdemo.test",
    require => File[ "/var/www/html/${domain}/basicfiles" ],
  }

  # Files for listedfiles.puppetdemo.test
  file { "/var/www/html/${domain}/listedfiles":
    ensure  => 'directory',
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    require => File[ "/var/www/html/${domain}" ],
  }
  file { "/var/www/html/${domain}/listedfiles/listedfile.txt":
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "This is a sample listed file @ listedfiles.puppetdemo.test",
    require => File[ "/var/www/html/${domain}/listedfiles" ],
  }

  # Files for internalfiles.puppetdemo.test
  file { "/var/www/html/${domain}/internalfiles":
    ensure  => 'directory',
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    require => File[ "/var/www/html/${domain}" ],
  }
  file { "/var/www/html/${domain}/internalfiles/internalfile.txt":
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "This is a sample internal file @ internalfiles.puppetdemo.test",
    require => File[ "/var/www/html/${domain}/internalfiles" ],
  }

  ####################################### End of example files and directories ####################################


  # This class creates two servers:
  # - https server that serves the content,
  # - http server that redirects to the https server.
  # It also controls the deploy of ssl certs and key for its domain using static_sslprefix.
  # This class always removes the default config file from the package
  # Note that server_default_create is set to false.
  # You should be able to browse https://files.puppetdemo.test/
  class { 'puppet_infrastructure::nginx_static':
    domain                  => 'files.puppetdemo.test',
    www_root                => "/var/www/html/${domain}/files",
    ssl                     => true,
    static_sslprefix        => 'star.puppetdemo.test',
    manage_ssl              => true,
    redirect_to_https       => true,
    redirect_to_www         => false,
    server_default_create   => false,
    allow_directory_listing => true,
    require                 => File[ "/var/www/html/${domain}/files" ],
  }

  # This defined type creates another https server that does NOT allow directory listing
  # Thefore, you won't be able to browse https://basicfiles.puppetdemo.test/ but you will
  # be able to wget https://basicfiles.puppetdemo.test/basicfile.txt
  puppet_infrastructure::nginx_static_domain { 'basicfiles.puppetdemo.test':
    domain                  => 'basicfiles.puppetdemo.test',
    www_root                => "/var/www/html/${domain}/basicfiles",
    ssl                     => true,
    static_sslprefix        => 'star.puppetdemo.test',
    manage_ssl              => false,
    allow_directory_listing => false,
    require                 => File[ "/var/www/html/${domain}/basicfiles" ],
  }

  # This defined type creates another https server that allows directory listing
  # You should be able to browse https://listedfiles.puppetdemo.test/
  puppet_infrastructure::nginx_static_domain { 'listedfiles.puppetdemo.test':
    domain                  => 'listedfiles.puppetdemo.test',
    www_root                => "/var/www/html/${domain}/listedfiles",
    ssl                     => true,
    static_sslprefix        => 'star.puppetdemo.test',
    manage_ssl              => false,
    allow_directory_listing => true,
    require                 => File[ "/var/www/html/${domain}/listedfiles" ],
  }

  # This defined type creates one https server that only allows access by clients with IPs between 10.103.21.1 and 10.103.21.0.254
  # If your IP is in ip_whitelist you should be able to browse https://internalfiles.puppetdemo.test/
  # If your IP is not in the whitelist you will get a '403 Forbidden' at https://internalfiles.puppetdemo.test/
  puppet_infrastructure::nginx_static_domain { 'internalfiles.pupetdemo.test':
    domain                  => 'internalfiles.puppetdemo.test',
    www_root                => "/var/www/html/${domain}/internalfiles",
    ssl                     => true,
    manage_ssl              => false,
    static_sslprefix        => 'star.puppetdemo.test',
    allow_directory_listing => true,
    ip_whitelist            => ['10.103.21.0/24'], #FIXME: edit if you need
    require                 => File[ "/var/www/html/${domain}/files" ],
  }

  # This defined type creates:
  # - https_www server, that serves the main content,
  # - http server that redirects to https_www,
  # - https server that redirects to https_www,
  # - the default server that listens to http and https, is accessed by IP and redirects to the https_www server, because redirect_default is set to true.
  # The https_www server would be accessed directly, in this example, by:
  # https://www.puppetdemo.test
  puppet_infrastructure::nginx_static_domain { 'puppetdemo.test':
    domain                => 'puppetdemo.test',
    www_root              => "/var/www/html/${domain}/site",
    ssl                   => true,
    manage_ssl            => false,
    static_sslprefix      => 'star.puppetdemo.test',
    redirect_to_https     => true,
    redirect_to_www       => true,
    server_default_create => true,
    redirect_default      => true,
    require               => File[ "/var/www/html/${domain}/site" ],
  }

}
