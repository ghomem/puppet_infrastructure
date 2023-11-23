### Purpose ########
# Our nginx frontend class does three things:
# - it installs nginx servers for the given domain (using our defined type
# nginx_frontend_domain);
# - it bundles the needed certificates (using our class ssl_nginx);
# - it creates a default server.
### Outputs ########
# - configured and running nginx servers
# - the bundled certificate and key are placed in (see our ssl_nginx_domain defined type)
#   "${ssl_certs_dir}/${domain}.nginx.bundle.crt",
#   "${ssl_private_dir}/${domain}.key",
### Inputs #########
# - the certificate, intermediate certificates and key should be in the expected input location (see our ssl_nginx_domain defined type)
### Dependencies ###
# - nginx must be installed (you can use our nginx_base class for this)
# - you will need a certificate and key for the needed domains (e.g. www.domain)

class puppet_infrastructure::nginx_frontend (
  # These are the same parameters as those of our defined type
  # nginx_frontend_domain, so their explanation is given there.
  # When we started the defaults here and in the default type
  # were the same (this may have changed in the meanwhile).
  $domain,
  $frontend_sslprefix = '',
  $backend_hosts_and_ports,
  $backend_protocol,
  # set to false to remove all virtual hosts created by nginx_frontend_domain
  Boolean $servers_create             = true,
  # Option to enable/disable SSL completely, disabling SSL could be useful:
  # - for testing before you have the SSL certificates
  # - for situations where it's not feasible to get an SSL certificate
  #   (e.g. duckdns.org domains or similar)
  Boolean $enable_ssl                 = true,
  Boolean $manage_ssl                 = true,
  Boolean $letsencrypt_certificate    = false,
  $domain_backend_pass_suffix         = '',
  $domain_backend_set_headers         = [],
  $www_fix_redirect                   = false,
  $decorate_naked                     = false,
  $additional_ssl_protocols           = [],
  $additional_ssl_ciphers             = [],
  $base_ssl_protocols_prefix          = ['TLSv1.3', ],
  $base_ssl_ciphers_prefix            = 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305',
  $base_ssl_ciphers_suffix            = '!DSS:!EXPORT',
  $base_ssl_ecdh_curve                = 'auto',
  $security_headers                   = false,
  $redirects_external_prevented       = false,
  $redirects_external_location        = 'forbidden-external-redirect',
  $redirects_external_whitelisted     = [],
  Array $proxy_locations_adhoc_config = [],
  # Issue #63 This parameter is not from the defined type nginx_frontend_domain
  # but instead it is used in this class directly
  Boolean $server_default_create      = true,
  # Issue #63 Set this to true for the default server
  # to return a redirect instead of a 404
  Boolean $redirect_default           = false,
  # Issue #63 Set this to true to create a monitoring server
  # with name: hostname_from_puppet_cert.monitoring.$domain
  Boolean $server_monitoring_create   = false,
  $proxy_locations_others_config      = [],
  # Issue #143 Support restriction per IP
  # If not changed, the default values for allow and deny are kept,
  # which means all IPs are allowed, if changed
  # all IPs are denied except the IPs in the array.
  # It's important to note that nginx processes requests in phases,
  # and $ip_whitelist affects directives (allow/deny) in the access phase,
  # so it won't have any effect in servers with "return" because that goes
  # in the rewrite phase, which happens first, so the parameters location_allow
  # and location_deny will be ignored and are only present in case they are to
  # be needed in the future.
  # http://www.nginxguts.com/2011/01/phases/
  Array $ip_whitelist                 = [],
  Boolean $use_compact_log_format     = false,
  Boolean $dynamic_dns_resolution     = false,
  Array $resolver                     = ['127.0.0.53 valid=10s'],
  # Issue #286 we expose the proxy timeout variables here, but they are used and documented in nginx_frontend_domain
  String $proxy_read_timeout          = '90s',
  String $proxy_connect_timeout       = '90s',
  String $proxy_send_timeout          = '90s',
) {

  # includes the nginx_base class, can get overriden
  require Class[ 'puppet_infrastructure::nginx_base' ]

  # Different OS families (can) require different locations for cert and/or
  # private directories
  case $::facts['os']['family'] {
    'RedHat': {
      $ssl_private_dir = '/etc/pki/tls/private'
      # In RedHat family there is a link pointing this directory to
      # /etc/pki/tls/certs so we can use that
      $ssl_certs_dir  = '/etc/ssl/certs'
    }
    # We consider Ubuntu be our default OS ('Debian' family)
    default:  {
      $ssl_private_dir = '/etc/ssl/private'
      $ssl_certs_dir  = '/etc/ssl/certs'
    }
  }

  # issue#16 This is needed for the default server below
  # This is not a class parameter so that it doesn't get bypassed by accident
  $base_ssl_prefer_server_ciphers = 'on'
  # issue#16 This is needed for the default site below
  # Our location of the DH custom group, this is created by the nginx_base class
  $base_dh_params = '/etc/nginx/dhparams.pem'

  # Issue #63 parse the create flag for the default server
  case $server_default_create {
    true    : { $server_default_ensure = 'present' }
    false   : { $server_default_ensure = 'absent' }
    default : { fail("Unexpected value of server_default_create='${server_default_create}'!") }
  }

  # issue#16 This is needed for the default server below
  # Add the additional protocols
  $base_ssl_protocols_array = concat($base_ssl_protocols_prefix, $additional_ssl_protocols)
  # Convert all protocols to string
  $base_ssl_protocols = join($base_ssl_protocols_array, ' ')

  # issue#16 This is needed for the default server below
  # Convert the additional ciphers to a : separated string
  $additional_ssl_ciphers_string = join($additional_ssl_ciphers, ':')
  # Joing the cipher strings
  $base_ssl_ciphers = "${base_ssl_ciphers_prefix}:${additional_ssl_ciphers_string}:${base_ssl_ciphers_suffix}"

  # This removes the default nginx config file from the package
  include puppet_infrastructure::nginx_default_removal

  # Issue #163 SSL can be managed from the class or from the defined type
  # This is managed by this class without help from the nginx_frontend_domain defined type,
  # because we have an HTTPS server in this class, the default server
  if ( $enable_ssl and $manage_ssl ) {
    puppet_infrastructure::ssl_nginx_domain { $frontend_sslprefix:
      sslprefix               => $frontend_sslprefix,
      letsencrypt_certificate => $letsencrypt_certificate,
    }
  }

  if ( $letsencrypt_certificate ) {
    $ssl_cert_path = "${ssl_certs_dir}/${frontend_sslprefix}.nginx.bundle.pem"
    $ssl_key_path = "${ssl_private_dir}/${frontend_sslprefix}-key.pem"
  } else {
    $ssl_cert_path = "${ssl_certs_dir}/${frontend_sslprefix}.nginx.bundle.crt"
    $ssl_key_path = "${ssl_private_dir}/${frontend_sslprefix}.key"
  }

  # issue#16 This is needed for the default server below
  # we might not want people to guess from the IP what service is running
  if ( $redirect_default == true ) {
    $default_str = "301 https://www.${domain}\$request_uri"
  }
  else {
    $default_str = '404'
  }

  # issue # 143
  if ($ip_whitelist == []) {
      # keep default values
      $allow = []
      $deny = []
  } else {
      $allow = $ip_whitelist
      $deny = ['all']
  }

  # issue#16 This didn't make it to the defined type nginx_frontend_base so
  # we're keeping it here: default server
  # the default server serves both HTTP on port 80 and HTTPS on port 443
  # it has a "" server name (which will match any Host not matched elsewhere and
  # an absent Host), it returns a redirect to https www server
  if $enable_ssl {
    $default_server_require = Puppet_infrastructure::Ssl_nginx_domain[$frontend_sslprefix]
  } else {
    $default_server_require = []
  }
  nginx::resource::server { 'default':
    ensure                    => $server_default_ensure,
    require                   => $default_server_require,
    # the empty server name is the default and it matches also the absence of the "Host" request header field
    server_name               => ['""'],
    # make sure this is the default server
    # (even if it is not the first one listed)
    listen_options            => 'default_server',
    # we will server both HTTP on port 80 and HTTPS on port 443
    listen_port               => 80,
    # issue #143
    location_allow            => $allow,
    location_deny             => $deny,
    ssl                       => $enable_ssl,
    ssl_port                  => 443,
    ssl_cert                  => $ssl_cert_path,
    ssl_key                   => $ssl_key_path,
    location_custom_cfg       => {
      'return' => $default_str,
    },
    format_log                => 'main',
    ssl_protocols             => $base_ssl_protocols,
    ssl_ciphers               => $base_ssl_ciphers,
    ssl_prefer_server_ciphers => $base_ssl_prefer_server_ciphers,
    ssl_dhparam               => $base_dh_params,
    server_cfg_ssl_append     => {
      'ssl_ecdh_curve' => $base_ssl_ecdh_curve,
    },

  }

  # Issue #63 parse the create flag for the monitoring server
  case $server_monitoring_create {
    true    : { $server_monitoring_ensure = 'present' }
    false   : { $server_monitoring_ensure = 'absent' }
    default : { fail("Unexpected value of server_monitoring_create='${server_monitoring_create}'!") }
  }

  # Issue #63 The monitoring server
  # Let's set a few parameters to make this easier to change/generalize
  # Here's the (subdomain) name we'll use
  $server_monitoring_name = 'monitoring'
  # And here's the text string that the monitoring server will return
  $server_monitoring_return = 'Hello World!\n'
  # Here's the HTTP server
  $fqdn_monitoring_server = "${::trusted['hostname']}.${server_monitoring_name}.${domain}"
  nginx::resource::server { $fqdn_monitoring_server:
    ensure              => $server_monitoring_ensure,
    server_name         => [ $fqdn_monitoring_server, ],
    # The "return" below ignores the location_allow and location_deny.
    # This happens because nginx processes requests in phases, and the
    # rewrite phase (return) goes before the access phase (allow/deny).
    # http://www.nginxguts.com/2011/01/phases/
    # location_allow and location_deny are kept just in case the code changes
    # in the future
    location_allow      => $allow,
    location_deny       => $deny,
    # this is the default but let's make it explicit
    ssl                 => false,
    # we will serve only HTTP (default port 80)
    listen_port         => 80,
    # as of now there's no argument for setting return via the puppet-nginx
    # module, so we'll add that as a custom config argument
    # (it will go into the default location)
    location_custom_cfg => {
      'return'       => "200 '${server_monitoring_return}'",
      # adding header for the browser to show the return as text like this
      # resulted in a duplicate header:
      # add_header          => { 'Content-Type' => 'text/plain', }
      # so instead we set the default_type
      # Reference: https://serverfault.com/questions/196929/reply-with-200-from-nginx-config-without-serving-a-file
      'default_type' => 'text/plain',
    },
  }

  # stub status page for monitoring vhost
  # only accessible from localhost
  nginx::resource::location { 'nginx_status':
    ensure         => $server_monitoring_ensure,
    location       => '/nginx_status',
    stub_status    => true,
    server         => $fqdn_monitoring_server,
    location_allow => [ '127.0.0.1', ],
    location_deny  => [ 'all', ],
  }

  if ( $server_monitoring_create ) {
    # edit hosts to curl with the correct interface
    host { $fqdn_monitoring_server: ip => '127.0.0.1' }

    # nginx status check
    $localdir = lookup('filesystem::localdir')

    file { "${localdir}/bin/check_nginx_status.py":
      mode    => '0755',
      owner   => 'root',
      group   => 'root',
      content => template('puppet_infrastructure/sysmon/check_nginx_status.py.erb'),
      require => File[ "${localdir}/bin" ],
    }
  }

  # issue#16 The remaining work is now done using the defined type
  puppet_infrastructure::nginx_frontend_domain {$domain:
    domain                         => $domain,
    frontend_sslprefix             => $frontend_sslprefix,
    backend_hosts_and_ports        => $backend_hosts_and_ports,
    backend_protocol               => $backend_protocol,
    domain_backend_pass_suffix     => $domain_backend_pass_suffix,
    domain_backend_set_headers     => $domain_backend_set_headers,
    www_fix_redirect               => $www_fix_redirect,
    decorate_naked                 => $decorate_naked,
    additional_ssl_protocols       => $additional_ssl_protocols,
    additional_ssl_ciphers         => $additional_ssl_ciphers,
    base_ssl_protocols_prefix      => $base_ssl_protocols_prefix,
    base_ssl_ciphers_prefix        => $base_ssl_ciphers_prefix,
    base_ssl_ciphers_suffix        => $base_ssl_ciphers_suffix,
    base_ssl_ecdh_curve            => $base_ssl_ecdh_curve,
    security_headers               => $security_headers,
    redirects_external_prevented   => $redirects_external_prevented,
    redirects_external_location    => $redirects_external_location,
    redirects_external_whitelisted => $redirects_external_whitelisted,
    proxy_locations_adhoc_config   => $proxy_locations_adhoc_config,
    proxy_locations_others_config  => $proxy_locations_others_config,
    ip_whitelist                   => $ip_whitelist,
    enable_ssl                     => $enable_ssl,
    # We have manage_ssl set to false because if we want to manage ssl,
    # we do it within the class, without depending on the defined type,
    # because we have a default server that serves HTTPS
    manage_ssl                     => false,
    letsencrypt_certificate        => $letsencrypt_certificate,
    use_compact_log_format         => $use_compact_log_format,
    servers_create                 => $servers_create,
    dynamic_dns_resolution         => $dynamic_dns_resolution,
    resolver                       => $resolver,
    proxy_read_timeout             => $proxy_read_timeout,
    proxy_connect_timeout          => $proxy_connect_timeout,
    proxy_send_timeout             => $proxy_send_timeout,
  }

}
