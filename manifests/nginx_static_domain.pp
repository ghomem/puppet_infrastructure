### Purpose ########
# Here 'domain' denotes this define type can be used to
# set up a set of servers (aka vhosts in apache) for a given domain in a nginx
# node (and can be declared multiple times to repeat for multiple domains)
### Outputs ########
# - configured and running nginx servers (see which ones in the code below) for
# the given domain
### Inputs #########
# - the bundled certificate and key should be in the expected input location
# (we can use our ssl_nginx class for that)
### Dependencies #######
# - nginx must be installed and a custom DH group created in the expected location (you can use our nginx_base class for this)
# - you will need a certificate and key for the needed domains if you intend to serve https
# For more documentation, read the comments in nginx_frontend_domain, and the wiki:
# https://bitbucket.org/asolidodev/puppet_infrastructure/wiki/NGINX%20Static%20server
define puppet_infrastructure::nginx_static_domain (
  String $domain,
  # The directory from which the files are served
  String $www_root,
  Boolean $servers_create                = true,
  String $static_sslprefix               = '',
  Boolean $manage_ssl                    = false,
  # Defined whether or not we're using letsencrypt generated certificates
  Boolean $letsencrypt_certificate       = false,
  # If true, we serve content through HTTPS, if false, we serve content through
  # HTTP
  Boolean $ssl                           = false,
  # This can only be true if $ssl is true
  Boolean $redirect_to_https             = false,
  # Redirects to http://www if we are serving HTTP,
  # redirects to https://www if we are serving HTTPS
  Boolean $redirect_to_www               = false,
  # $server_default_create is false here by default, but in the nginx_static
  # class is true by default
  # WARNING: this parameter can only be set to true once
  Boolean $server_default_create         = false,
  # This option is useful if you want the website accessible by IP
  # WARNING: setting this parameter to true with the 'ssl' parameter above
  #          also set to true will result in HTTP -> HTTPS redirection,
  #          even it 'redirect_to_https' is set to false
  Boolean $redirect_default              = false,
  # Shows directory structure if true
  Boolean $allow_directory_listing       = false,
  Array $additional_ssl_protocols        = [],
  Array $additional_ssl_ciphers          = [],
  Array $base_ssl_protocols_prefix       = ['TLSv1.2', ],
  String $base_ssl_ciphers_prefix        = 'DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA',
  String $base_ssl_ciphers_suffix        = '!DSS:!EXPORT',
  String $base_ssl_ecdh_curve            = 'prime256v1',
  Array $ip_whitelist                    = [],
  # be careful not to override other configs
  Hash $adhoc_configs                    = {},
  Integer $http_port                     = 80,
  Integer $https_port                    = 443,
) {

  # includes the nginx_base class, can get overriden
  require Class[ 'puppet_infrastructure::nginx_base' ]

  # This removes the default nginx config file from the package
  include puppet_infrastructure::nginx_default_removal

  case $::facts['os']['family'] {
    'RedHat': {
      $ssl_private_dir = '/etc/pki/tls/private'
      $ssl_certs_dir  = '/etc/ssl/certs'
    }
    default:  {
      $ssl_private_dir = '/etc/ssl/private'
      $ssl_certs_dir  = '/etc/ssl/certs'
    }
  }

  if ( $manage_ssl ) {
    if ( !$ssl or $static_sslprefix == '' ) {
      fail('manage_ssl can only be true when ssl is true and static_sslprefix has a value!')
    }
    else {
      puppet_infrastructure::ssl_nginx_domain { $static_sslprefix:
        sslprefix               => $static_sslprefix,
        letsencrypt_certificate => $letsencrypt_certificate,
      }
    }
  }

  if ( $letsencrypt_certificate ) {
    $ssl_cert_path = "${ssl_certs_dir}/${static_sslprefix}.nginx.bundle.pem"
    $ssl_key_path = "${ssl_private_dir}/${static_sslprefix}-key.pem"
  } else {
    $ssl_cert_path = "${ssl_certs_dir}/${static_sslprefix}.nginx.bundle.crt"
    $ssl_key_path = "${ssl_private_dir}/${static_sslprefix}.key"
  }

  $base_ssl_prefer_server_ciphers = 'on'
  $base_dh_params = '/etc/nginx/dhparams.pem'
  $base_ssl_protocols_array = concat($base_ssl_protocols_prefix, $additional_ssl_protocols)
  $base_ssl_protocols = join($base_ssl_protocols_array, ' ')
  $additional_ssl_ciphers_string = join($additional_ssl_ciphers, ':')
  $base_ssl_ciphers = "${base_ssl_ciphers_prefix}:${additional_ssl_ciphers_string}:${base_ssl_ciphers_suffix}"

  if ( $ip_whitelist == [] ) {
      $allow = []
      $deny = []
  } else {
      $allow = $ip_whitelist
      $deny = ['all']
  }

  # Force $redirect_to_https to be false if $ssl is false
  if ( $redirect_to_https and !$ssl ) {
    fail('You can only redirect to https when ssl is set to true!')
  }

  if ($static_sslprefix == '' and $ssl) {
    fail('You need to provide a value for static_sslprefix!')
  }

  case $allow_directory_listing {
    true    : { $autoindex = 'on' }
    false   : { $autoindex = 'off' }
    default : { fail("Unexpected value of directory_listing_server='${allow_directory_listing}'!") }
  }

  # Change all ensure variables to "absent" if $servers_create is false
  if ( !$servers_create ) {
    $server_default_ensure        = 'absent'
    $redirect_ensure              = 'absent'
    $redirect_to_https_www_ensure = 'absent'
    $http_ensure                  = 'absent'
    $https_ensure                 = 'absent'
    $server_name                  = "www.${domain}"
    $redirect_names               = [$domain, "www.${domain}"]
    $redirect_string              = "301 https://www.${domain}\$request_uri"
  } else {
    # We decide if we want to serve HTTP or HTTPS
    case ( $ssl ) {
      true    : {
        $https_ensure = 'present'
        $http_ensure  = 'absent'
      }
      false   : {
        $http_ensure  = 'present'
        $https_ensure = 'absent'
      }
      default : { fail("Unexpected value of ssl='${ssl}'!") }
    }

    case $server_default_create {
      true    : { $server_default_ensure = 'present' }
      false   : { $server_default_ensure = 'absent' }
      default : { fail("Unexpected value of server_default_create='${server_default_create}'!") }
    }

    # All the logic of server redirection goes here
    if ( $redirect_to_https or $redirect_to_www ) {
      # If we want any redirecting, the main_redirector server is created
      $redirect_ensure = 'present'
      if ( $redirect_to_https and $redirect_to_www ) {
        # In this case we want our main server to be https://www
        $redirect_string = "301 https://www.${domain}\$request_uri"
        # We make sure our main server only responds to requests to www
        $server_name = "www.${domain}"
        # This is the only case when we need our https_www_redirector server
        $redirect_to_https_www_ensure = 'present'
        # Our main_redirector server has two names, so it accepts requests to
        # http with and without www, and redirects to https://www
        $redirect_names = [$domain, "www.${domain}"]
      } elsif ( $redirect_to_https and !$redirect_to_www ) {
        # In this case we want our main server to be https without www
        $redirect_string = "301 https://${domain}\$request_uri"
        # We make sure our main server only responds to requests without www
        $server_name = $domain
        # Our main_redirector server domain is without www
        $redirect_names = [$domain]
        # The only servers we create are the main_redirector and the main https server
        # We don't need the https_www_redirector server
        $redirect_to_https_www_ensure = 'absent'
      } elsif ( !$redirect_to_https and $redirect_to_www ) {
        # In this case we want our main server to be http with www
        $redirect_string = "301 http://www.${domain}\$request_uri"
        # The name of our main http server includes www
        $server_name = "www.${domain}"
        # The name of our main_redirector server doesn't include www
        $redirect_names = [$domain]
        # The only servers we create are the main_redirector and the main http
        # server. We don't need the https_www_redirector server
        $redirect_to_https_www_ensure = 'absent'
      }
    } else {
      # In this case there are no redirects, except the default if true, we only
      # want to create the main http server for sure
      $redirect_ensure = 'absent'
      # Our server name doesn't include www
      $server_name = $domain
      # We make sure the https_www_redirector server isn't created
      $redirect_to_https_www_ensure = 'absent'
      # The default server needs to redirect to our http server without www
      if $ssl {
        $redirect_string = "301 https://${domain}\$request_uri"
      } else {
        $redirect_string = "301 http://${domain}\$request_uri"
      }
      $redirect_names = [$domain]
    }
  }

  if ( $redirect_default == true ) {
    $default_str = $redirect_string
  }
  else {
    $default_str = '404'
  }

  # The $default_server_configs hash adds the ssl configuration
  # to the default server, but only if our main server
  # is serving https
  if ( $ssl ) {
    $default_server_configs = {
      ssl                       => true,
      ssl_port                  => $https_port,
      ssl_cert                  => $ssl_cert_path,
      ssl_key                   => $ssl_key_path,
      format_log                => 'main',
      ssl_protocols             => $base_ssl_protocols,
      ssl_ciphers               => $base_ssl_ciphers,
      ssl_prefer_server_ciphers => $base_ssl_prefer_server_ciphers,
      ssl_dhparam               => $base_dh_params,
      server_cfg_ssl_append     => {
        'ssl_ecdh_curve' => $base_ssl_ecdh_curve,
      },
    }
  } else {
    $default_server_configs = {}
  }

  nginx::resource::server { "static_default_${domain}":
    ensure              => $server_default_ensure,
    server_name         => ['""'],
    listen_port         => $http_port,
    listen_options      => 'default_server',
    location_allow      => $allow,
    location_deny       => $deny,
    location_custom_cfg => {
      'return' => $default_str
    },
    # Adds the ssl configs
    *                   => $default_server_configs,
  }

  # This http server redirects to http_www or https or https_www, depending on
  # the values of redirect_to_https and redirect_to_www
  nginx::resource::server { "static_main_redirector_${domain}":
    ensure              => $redirect_ensure,
    server_name         => $redirect_names,
    listen_port         => $http_port,
    location_allow      => $allow,
    location_deny       => $deny,
    location_custom_cfg => {
      'return' => $redirect_string
    },
  }

  # This https server is only created when we want to redirect to https_www
  nginx::resource::server { "static_https_www_redirector_${domain}":
    ensure                    => $redirect_to_https_www_ensure,
    server_name               => [$domain, ],
    listen_port               => $https_port,
    location_allow            => $allow,
    location_deny             => $deny,
    ssl                       => true,
    ssl_port                  => $https_port,
    ssl_cert                  => $ssl_cert_path,
    ssl_key                   => $ssl_key_path,
    ssl_protocols             => $base_ssl_protocols,
    ssl_ciphers               => $base_ssl_ciphers,
    ssl_prefer_server_ciphers => $base_ssl_prefer_server_ciphers,
    ssl_dhparam               => $base_dh_params,
    server_cfg_ssl_append     => {
      'ssl_ecdh_curve' => $base_ssl_ecdh_curve,
    },
    location_custom_cfg       => {
      'return' => $redirect_string
    },
  }

  # The main http server, is only created if $ssl is false
  nginx::resource::server { "static_http_${domain}":
    ensure         => $http_ensure,
    server_name    => [$server_name,],
    www_root       => $www_root,
    listen_port    => $http_port,
    autoindex      => $autoindex,
    location_allow => $allow,
    location_deny  => $deny,
  }

  # The main https server, is only created if $ssl is true
  nginx::resource::server { "static_https_${domain}":
    ensure                    => $https_ensure,
    server_name               => [$server_name, ],
    www_root                  => $www_root,
    listen_port               => $https_port,
    autoindex                 => $autoindex,
    location_allow            => $allow,
    location_deny             => $deny,
    ssl                       => true,
    ssl_port                  => $https_port,
    ssl_cert                  => $ssl_cert_path,
    ssl_key                   => $ssl_key_path,
    ssl_protocols             => $base_ssl_protocols,
    ssl_ciphers               => $base_ssl_ciphers,
    ssl_prefer_server_ciphers => $base_ssl_prefer_server_ciphers,
    ssl_dhparam               => $base_dh_params,
    server_cfg_ssl_append     => {
      'ssl_ecdh_curve' => $base_ssl_ecdh_curve,
    },
    *                         => $adhoc_configs,
  }

}
