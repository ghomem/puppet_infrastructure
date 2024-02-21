### Purpose ########
# This class provides the web interface to Hashman

### Outputs ########
# - python based web server httpserver.py and related utils
# - systemd service

### Inputs #########
# - the certificate, intermediate certificates and key should be in the expected input location (see our ssl_nginx class)

### Dependencies ###
#  packages: nginx, python, python3-flask, gunicorn
#
#  classes:
#    puppet_infrastructure::nginx_frontend
#    puppet_infrastructure::ssl_nginx
#    puppet_infrastructure::hashman
#
#  hiera: see below
class puppet_infrastructure::hashman_web (
  $letsencrypt_certificate = false,
) {

  $hashmandir             = lookup('hashman::bindir')
  $logdir                 = lookup('hashman::logdir')
  $address                = lookup('hashman::address')
  $hashmancustomname      = lookup('hashman::customname')
  $hashmancompany         = lookup('hashman::company')
  $companywebsite         = lookup('hashman::companywebsite')
  $localdir               = lookup('filesystem::localdir')
  $sslprefix              = lookup('hashman::sslprefix')
  $hashmancompanylogo     = lookup( { 'name' => 'hashman::companylogo', 'default_value' => 'img/logo.png' } )
  $hashmancompanylogomail = lookup( { 'name' => 'hashman::companylogomail', 'default_value' => 'img/logo-email.png' } )
  $client_side_timeout    = lookup( { 'name' => 'hashman::client_side_timeout', 'default_value' => 600 } )
  $server_side_timeout    = lookup( { 'name' => 'hashman::server_side_timeout', 'default_value' => 1800 } )
  $session_expiration     = lookup( { 'name' => 'hashman::active_session_expiration', 'default_value' => 'False' } )

  # get minpassword len and relax pass requirements vars
  $minpasswordlen = lookup({ name => 'hashman::minpasswordlen' , default_value => '6' })
  $relaxpassword  = lookup({ name => 'hashman::relaxpassword'  , default_value => true })

  $basemsg_l = 'For security reasons passwords must avoid dictionary words and must mix numbers with '
  $basemsg_r = join ( ['letters and symbols. The minimum password size is ', $minpasswordlen, ' characters. Allowed symbols are !?#$%&*@+-._=;:|/' ] )

  if ( $relaxpassword != true )
  {
    $basemsg_m = 'uppercase letters, lowercase '
  }
  else
  {
    $basemsg_m = ''
  }

  # used by httpserver.py and customvalidation.js
  $strpassmsg = join ( [ $basemsg_l, $basemsg_m, $basemsg_r ] )

  # hashman web facing code, recursive copy
  file { "${hashmandir}/httpserver/":
    ensure  => directory,
    source  => 'puppet:///modules/puppet_infrastructure/hashman/httpserver',
    recurse => true,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    notify  => Service[ 'hashman' ],
    require =>  Class[ 'puppet_infrastructure::hashman_base' ],
  }

  # this file is outside the tree because it has configurable parameters
  file { "${hashmandir}/httpserver/httpserver.py":
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => template('puppet_infrastructure/hashman/httpserver/httpserver.py.erb'),
    require => File[ "${hashmandir}/httpserver" ],
    notify  => Service[ 'hashman' ],
  }

  # same for this one
  file { "${hashmandir}/httpserver/static/js/customvalidation.js":
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => template('puppet_infrastructure/hashman/httpserver/static/js/customvalidation.js.erb'),
    require => File[ "${hashmandir}/httpserver" ],
    notify  => Service[ 'hashman' ],
  }

  # same for this one
  file { "${hashmandir}/httpserver/templates/next.html":
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => template('puppet_infrastructure/hashman/httpserver/templates/next.html.erb'),
    require => File[ "${hashmandir}/httpserver" ],
    notify  => Service[ 'hashman' ],
  }


  file { "${hashmandir}/httpserver/static/img/":
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }

  if $hashmancompanylogo == 'img/logo.png' {
    # this file is outside the tree because we don't want it to be overwritten
    file { "${hashmandir}/httpserver/static/img/logo.png":
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      replace => 'yes',
      source  => 'puppet:///modules/puppet_infrastructure/hashman/extra/logo.png',
      require => File[ "${hashmandir}/httpserver", "${hashmandir}/httpserver/static/img/" ],
    }
  } else {
    file { "${hashmandir}/httpserver/static/img/logo.png":
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      replace => 'yes',
      source  => "${hashmancompanylogo}",
      require => File[ "${hashmandir}/httpserver", "${hashmandir}/httpserver/static/img/" ],
    }
  }

  if $hashmancompanylogomail == 'img/logo-email.png' {
    # this file is outside the tree because we don't want it to be overwritten
    file { "${hashmandir}/httpserver/static/img/logo-email.png":
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      replace => 'yes',
      source  => 'puppet:///modules/puppet_infrastructure/hashman/extra/logo-email.png',
      require => File[ "${hashmandir}/httpserver", "${hashmandir}/httpserver/static/img/" ],
    }
  } else {
    file { "${hashmandir}/httpserver/static/img/logo-email.png":
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      replace => 'yes',
      source  => "${hashmancompanylogomail}",
      require => File[ "${hashmandir}/httpserver", "${hashmandir}/httpserver/static/img/" ],
    }
  }

  file { "${hashmandir}/httpserver/static/img/valid.png":
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    replace => 'no',
    source  => 'puppet:///modules/puppet_infrastructure/hashman/extra/valid.png',
    require => File[ "${hashmandir}/httpserver", "${hashmandir}/httpserver/static/img/" ],
  }

  # the log directory
  file { $logdir:
    ensure => directory,
    mode   => '0644',
    owner  => 'root',
    group  => 'root',
  }

  # the systemd startup script
  file { '/lib/systemd/system/hashman.service':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => template('puppet_infrastructure/hashman/hashman.service.erb'),
  }

  package { [ 'gunicorn', 'python3-flask' ]: ensure => present, }

  service { 'hashman':
    ensure   => running,
    provider => 'systemd',
    enable   => true,
    require  => File[ '/lib/systemd/system/hashman.service', "${hashmandir}/httpserver/httpserver.py" ],
  }

  # nginx - we use our own nginx configuration class

  class {'puppet_infrastructure::nginx_frontend':
    domain                     => $address,
    frontend_sslprefix         => $sslprefix,
    backend_hosts_and_ports    => ['127.0.0.1:8080', ],
    backend_protocol           => 'http',
    domain_backend_pass_suffix => '',
    www_fix_redirect           => true,
    redirect_default           => false,
    decorate_naked             => false,
    letsencrypt_certificate    => $letsencrypt_certificate,
  }

}
