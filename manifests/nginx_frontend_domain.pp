### Purpose ########
# Here 'domain' denotes this define type can be used to
# set up a set of servers (aka vhosts in apache) for a given domain
# in a nginx node (and can be declared multiple times to repeat for
# multiple domains)
### Outputs ########
# - configured and running nginx servers (see which ones in the code below)
# for the given domain
### Inputs #########
# - the bundled certificate and key should be in the expected input location
# (we can use our ssl_nginx class for that)
### Dependencies ###
# - nginx must be installed and a custom DH group created in the expected
# location (you can use our nginx_base class for this)
# - you will need a certificate and key for the needed domains (e.g. www.domain)
# WARNING: from release 1.1.48 this class depends on module puppet-nginx (v2.1.1)
### Warnings ###
# Issue#16 We don't setup a default server in this defined type (currently you
# can use nginx_frontend class for that)

define puppet_infrastructure::nginx_frontend_domain (
  # To remove a frontend, set the servers_create parameter to false
  # so that all servers are removed, which right now can be up to 4 servers:
  # http naked domain, https naked domain, http www domain, https www domain.
  # We used to also create the servers http m domain, https m domain, but they have been removed since issue #151.
  # Setting this to false also removes the upstream created to be used by these servers.
  Boolean $servers_create          = true,
  $domain,
  $frontend_sslprefix = '',
  $backend_hosts_and_ports,
  $backend_protocol,
  # Option to enable/disable SSL completely, disabling SSL could be useful:
  # - for testing before you have the SSL certificates
  # - for situations where it's not feasible to get an SSL certificate
  #   (e.g. duckdns.org domains or similar)
  Boolean $enable_ssl              = true,
  # Manage our own SSL, default is false to keep backwards compability
  Boolean $manage_ssl              = false,
  Boolean $letsencrypt_certificate = false,
  # The domain backend can serve only www.$domain, only $domain or both
  $domain_backend_pass_suffix      = '',
  $domain_backend_set_headers      = [],
  $www_fix_redirect                = false,
  # TL;DR: if your domain is 'example.com' and you're using this to setup the
  # www.example.com server, then change this to true. If not (i.e. your domain
  # is 'something.example.com'), then leave it false (default). For historical
  # reasons we started with the main nginx frontend server being www.$domain.
  # This makes sense when $domain is e.g. 'example.com', so that you get a
  # www.example.com server. As it turns out it does not make so much sense when
  # $domain is e.g. 'something.example.com' as you get a
  # www.something.example.com server. Setting this flag to true has two effects:
  # - the http://$domain server will return a redirect to the
  # https://www.$domain server (instead of a redirect to the https://$domain
  # server)
  # - a separate https://$domain server is created that returns a redirect to
  # https://www.$domain (instead of https://$domain being served directly using
  # the main server that proxies the backend)
  $decorate_naked                 = false,
  # Regardless of $decorate_naked, we may want or (not) a http://www.$domain
  # server to do the redirect to https://www.$domain. For example you may want
  # this even with $decorated_naked false (i.e. you're not redirecting
  # http://$domain and https://$domain both to https://www.$domain, but you do
  # want to redirect http://www.$domain to https://www.$domain and serve that).
  # This flag enables to toggle such redirect server (regardless of
  # $decorate_naked).
  Boolean $redirect_http_www_to_https_www_create = true,
  # When $domain is e.g. 'something.example.com', besides not serving
  # http://www.$domain (with a redirect to https://www.$domain) you may also
  # want not to serve https://www.$domain at all. This flag enables you to do
  # that. It doesn't make sense to set this flag to true but then have
  # $decorate_naked false (because you would not serve anything!) or
  # $redirect_http_www_to_https_www_create true (because you would redirect to
  # an absent server!)
  # so these conditions are checked and we fail it this happens.
  Boolean $server_https_www_create = true,
  # SSL/TLS References considered:
  #   https://www.ssllabs.com/ssltest/
  #   https://github.com/ssllabs/research/wiki/SSL-Server-Rating-Guide
  #   https://github.com/ssllabs/research/wiki/SSL-and-TLS-Deployment-Best-Practices
  #   https://mozilla.github.io/server-side-tls/ssl-config-generator/
  #   https://weakdh.org/
  #   https://safecurves.cr.yp.to/
  #   https://github.com/cloudflare/sslconfig/blob/master/conf
  # For ssl_protocols, we enter the ones from the mozilla generated 'modern'
  # configuration for Ubuntu 20.04 (nginx 1.18.0 and openssl 1.1.1f)
  #   https://ssl-config.mozilla.org/#server=nginx&version=1.18.0&config=modern&openssl=1.1.1f&guideline=5.7
  # Note: they are some parameters below (like $base_ssl_ciphers_prefix) to select the ciphers
  #       allowed and such, these parameters are meant for TLS versions older than 1.3; for TLSv1.3
  #       there is another parameter for nginx configurations, but we didn't find any reason to use
  #       it yet, see:
  #       https://github.com/mozilla/ssl-config-generator/issues/124
  $base_ssl_protocols_prefix = ['TLSv1.3', ],
  # AdditionaL SSL protocols we might want to enable (e.g. TLSv1.1, TLSv1.2, ...)
  # they will be appended to $base_ssl_protocols_prefix
  $additional_ssl_protocols       = [],
  # The parameters below:
  # - $base_ssl_ciphers_prefix
  # - $base_ssl_ciphers_suffix
  # - $additional_ssl_ciphers
  # do not have any effect on TLSv1.3, they are meant for older TLS versions
  # For ssl_ciphers
  #    1) we start with the ciphers from the mozilla generated 'intermediate'
  #    configurations for ubuntu 2.04(same nginx and openssl versions)
  #    https://ssl-config.mozilla.org/#server=nginx&version=1.18.0&config=intermediate&openssl=1.1.1f&guideline=5.7
  #    https://mozilla.github.io/server-side-tls/ssl-config-generator/?server=nginx-1.10.3&openssl=1.0.2g&hsts=yes&profile=intermediate
  #    2) we append !EXPORT
  #    3) we remove the DHE and ECDHE ciphers with DES (which Qualys considers
  #    weak)
  # Thus we get (the additional ciphers go in between)
  $base_ssl_ciphers_prefix = 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305',
  $base_ssl_ciphers_suffix = '!DSS:!EXPORT',
  $additional_ssl_ciphers         = [],
  # The $base_ssl_ecdh_curve parameter below has no effect on TLSv1.3 it's meant
  # for older TLS versions, technical notes below.
  # In the past:
  # - on nginx<1.11.0 we couldn't specify multiple curves
  # - on nginx<1.11.0 the default ecdh curve used to be 'prime256v1'
  # - on openssl<1.1.0 we didn't have 'X25519', we had 'brainpoolP384t1' which is
  #   not safe but still safer than 'prime256v1', but that was not supported by
  #   the Chrome and Safari versions of the time
  # so we used to default to 'prime256v1' for Ubuntu 16.04 in hope we could
  # upgrade to 'X25519' in the future, now we have newer openssl versions on
  # Ubuntu 20.04 and 22.04, so we are defaulting this parameter to 'auto'
  $base_ssl_ecdh_curve = 'auto',
  # With this option we activate security headers such as 'X-Frame-Options'
  # and 'X-XSS-Protection'
  $security_headers = false,
  # Issue is_puppet_base #104
  # This is to configure the value of the header 'X-Frame-Options'
  # which is set when security_headers is true.
  # WARNING Beware the OSWAP quote in caps:
  # "BE CAREFUL ABOUT DEPENDING ON ALLOW-FROM. If you apply it and the browser
  # does not support it, then you will have NO clickjacking defense in place."
  # Reference: https://www.owasp.org/index.php/Clickjacking_Defense_Cheat_Sheet
  # From the same reference, it appears that Chrome and Safari do NOT support
  # this header and instead support CSP frame-ancestors, so that should be in
  # place
  String $x_frame_options_value = 'SAMEORIGIN',
  # If this is set to true, external redirects are prevented and
  # rewritten to go to a frontend location (see below)
  $redirects_external_prevented = false,
  # When $redirects_external_prevented is true
  # external redirects are sent to this frontend location instead:
  $redirects_external_location = 'forbidden-external-redirect',
  # When $redirects_external_prevented is set to true
  # you can still allow redirects to specific hosts
  # by including them in this list of regular expressions
  $redirects_external_whitelisted = [],
  # Issue#82 Besides blocking external redirects and allowing for some of them
  # we may need to rewrite a redirect, so we add an ad-hoc parameter for this
  # which is an array-of-strings that is passed as a raw config
  # Use strings WITH trailing ";" (this is what the underlying puppet-nginx
  # expects)
  # WARNING#1 This is an ad-hoc config so write the directive in the string
  # (e.g. 'proxy_redirect URL1 URL2;')
  # WARNING#2 $redirects_external_whitelisted gets processed first, so that
  # takes precedence (i.e. if you set a URL both in
  # $redirects_external_whitelisted AND as a replacement in
  # $redirects_external_prevented_adhoc_config, then no replacement takes place)
  # WARNING#3 Notice this config is only applied if redirects_external_prevented
  # is set to true (because in that case we need this config placed just before
  # blocking all remaing redirects).
  # WARNING#4 If you are setting $redirects_external_prevented to false, then
  # you can use instead the $proxy_locations_adhoc_config to configure the
  # redirect replacements at will.
  Array $redirects_external_prevented_adhoc_config = [],
  # Issue#82 The parameter $proxy_locations_adhoc_config is an array-of-strings
  # that gets passed to the main location with proxy_pass
  # and with that you can pass e.g. subs_filter_types and subs_filter
  # directives. Use strings WITH trailing ";" (this is what the underlying
  # puppet-nginx expects)
  Array $proxy_locations_adhoc_config = [],
  # Issue#82 The parameter $proxy_locations_ignore_headers is an
  # array-of-strings that gets passed to the main location with proxy_pass and
  # with that you can set any header to be ignored.
  # Use strings WITHOUT trailing ";" (this is what the underlying puppet-nginx
  # expects)
  Array $proxy_locations_ignore_headers = [],
  # Issue #121 requires the support for further locations (i.e. non root) and
  # their individual configs
  # This is an list of hashes where
  # - the location key is mandatory (it is used for naming);
  # - keys from the root location that are not declared are inherited from the
  # root location
  # - keys from the root location that are declared are overriden by this
  # declaration
  # - keys not present on the root location are passed to this new location
  # We have a special raw_append behaviour: it is _ADDED_ to the raw_append of
  # the root location but any other parameters have the usual behavior that they
  # _OVERRIDE_ those of the root location.
  # Example:
  # $proxy_locations_others_config = {
  #   {
  #     'location'          => '/some/special/location/'
  #     'raw_append'        => 'some ad-hoc lua configs here, which are ADDED to some ad-hoc substitution configs from the root location'
  #     'proxy'             => 'a proxy (i.e. upstream server) parameter thus OVERRIDING the one from the root location',
  #     'proxy_hide_header' => 'some other parameter here not defined for the root location so we just get this NEW parameter's value',
  #   },
  # }
  # Here 'others' means not root and not our special location to serve after a
  # forbidden redirect is intercepted.
  $proxy_locations_others_config = [],
  # Issue #143 Support restriction per IP,
  # if not changed, the default values for allow and deny are kept,
  # which means all IPs are allowed, if changed
  # all IPs are denied except the IPs in the array.
  # It's important to note that nginx processes requests in phases,
  # and $ip_whitelist affects directives (allow/deny) in the access phase,
  # so it won't have any effect in servers with "return" because that goes
  # in the rewrite phase, which happens first, so the parameters location_allow
  # and location_deny will be ignored and are only present in case they are to
  # be needed in the future.
  # http://www.nginxguts.com/2011/01/phases/
  Array $ip_whitelist = [],
  Boolean $use_compact_log_format = false,
  # configure nginx so that the name to address resolution for upstream servers is done periodically
  Boolean $dynamic_dns_resolution = false,
  # define resolver and local ttl for cached DNS records
  # requires $dynamic_dns_resolution to be true
  # Syntax example ['127.0.0.1 valid=10s']
  Array $resolver = ['127.0.0.53 valid=10s'],
  # Issue #286 we expose the proxy timeout variables here to avoid timeouts when a web request is waiting for a response
  # from some server side process that can take more than 90 seconds, for example, zipping large files.
  # These variables seems to work with both '90s' and '90', but to stay consistent with NGINX configs, we will always use '90s'
  # http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_read_timeout
  # NGINX default is '60s', but the upstream puppet module uses '90s', so we keep that
  String $proxy_read_timeout = '90s',
  # http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_connect_timeout
  # NGINX default is '60s', they note "this timeout cannot usually exceed 75 seconds", but the upstream puppet module uses '90s', so we keep that
  String $proxy_connect_timeout = '90s',
  # http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_send_timeout
  # NGINX default is '60s', but the upstream puppet module uses '90s', so we keep that
  String $proxy_send_timeout = '90s',
) {

  # check here for data type so we fail before we do anything
  # Example: ['localhost:8080', 'localhost:8081', ... ]
  if ( type($backend_hosts_and_ports) =~ Type[Array] ){
    # check documentation for reduce here: https://puppet.com/docs/puppet/5.5/function.html#reduce
    $nginx_upstream_members = $backend_hosts_and_ports.reduce({}) | $previous_return, $backend_host_element | {
      $element_split = split($backend_host_element, ':')
      $new_hash_element = {
                            "${backend_host_element} in ${title}" => {
                              server => $element_split[0],
                              # we need to sum a zero here so we can cast this variable to integer
                              # reference: https://puppet.com/docs/puppet/5.5/lang_data_number.html#converting-strings-to-numbers
                              port   => $element_split[1] + 0,
                            },
                          }
      $previous_return.merge($new_hash_element)
    }
    notify {"Generated Upstream members for ${title} are: ${nginx_upstream_members}" : loglevel => 'debug' }
  }
  elsif ( type($backend_hosts_and_ports) =~ Type[Hash] ) {
    # here we just deliver the variable as such
    # because is already the propper sintax
    $nginx_upstream_members = $backend_hosts_and_ports
    notify { "Upstream members for ${title} are: ${nginx_upstream_members}" : loglevel => 'debug' }
  }
  else {
    fail('$backend_hosts_and_ports should be either an Array of strings or a Hash of Hashes')
  }

  # includes the nginx_base class, can get overriden
  require Class[ 'puppet_infrastructure::nginx_base' ]

  # This removes the default nginx config file from the package
  include puppet_infrastructure::nginx_default_removal

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

  # parse the servers_create flag into servers_ensure absent or present
  if ( $servers_create ) {
    $servers_ensure = 'present'
  } else {
    $servers_ensure = 'absent'
  }

  # if we choose to not serve https_www....
  if ( ! $server_https_www_create) {
    # then it makes no sense to redirect http_www requests to it
    if ($redirect_http_www_to_https_www_create) {
      fail("\nYou have set parameters\n  server_https_www_create='${server_https_www_create}'\nand\n  redirect_http_www_to_https_www_create='${redirect_http_www_to_https_www_create}'\nBut it makes no sense to serve on http www a redirect to https www if you are not creating this last server! Please change one of these settings.")
    }
    # and it makes no sense to redirect http (non www) redirects to it
    if ($decorate_naked) {
      fail("\nYou have set parameters\n  server_https_www_create='${server_https_www_create}'\nand\n  decorate_naked='${decorate_naked}'\nBut it makes no sense to serve on http (non www) a redirect to https www if you are not creating this last server! Please change one of these settings.")
    }
  }

  # This is not a class parameter so that it doesn't get bypassed by accident
  $base_ssl_prefer_server_ciphers = 'on'
  # Our location of the DH custom group, this is created by the nginx_base class
  $base_dh_params = '/etc/nginx/dhparams.pem'

  # Add the additional protocols
  $base_ssl_protocols_array = concat($base_ssl_protocols_prefix, $additional_ssl_protocols)
  # Convert all protocols to string
  $base_ssl_protocols = join($base_ssl_protocols_array, ' ')

  # Convert the additional ciphers to a : separated string
  $additional_ssl_ciphers_string = join($additional_ssl_ciphers, ':')
  # Joing the cipher strings
  $base_ssl_ciphers = "${base_ssl_ciphers_prefix}:${additional_ssl_ciphers_string}:${base_ssl_ciphers_suffix}"

  # issue # 143
  if ($ip_whitelist == []) {
      # keep default values
      $allow = []
      $deny = []
  } else {
      $allow = $ip_whitelist
      $deny = ['all']
  }

  if ( $manage_ssl ) {
    puppet_infrastructure::ssl_nginx_domain { $frontend_sslprefix:
      sslprefix               => $frontend_sslprefix,
      letsencrypt_certificate => $letsencrypt_certificate,
    }
  }

  if $enable_ssl {
    if ( $letsencrypt_certificate ) {
      $ssl_cert_path = "${ssl_certs_dir}/${frontend_sslprefix}.nginx.bundle.pem"
      $ssl_key_path = "${ssl_private_dir}/${frontend_sslprefix}-key.pem"
    } else {
      $ssl_cert_path = "${ssl_certs_dir}/${frontend_sslprefix}.nginx.bundle.crt"
      $ssl_key_path = "${ssl_private_dir}/${frontend_sslprefix}.key"
    }
  } else {
    $ssl_cert_path = false
    $ssl_key_path = false
  }

  # Issue #31
  # When $redirects_external_prevented is true, the
  # external redirects are sent to this location instead:
  if ( $redirects_external_prevented) {
    $redirects_external_location_ensure = 'present'
    $my_whitelist = $redirects_external_whitelisted.map |String $value| {
      "proxy_redirect ~(${value}) \$1;"
    }
    $redirects_external_prevent_config = concat (
      [ 'proxy_redirect / /;' , "proxy_redirect ~(https?:\/\/)(.+\.)?(${domain})(\/.*)? \$1\$2\$3\$4;" ],
      $my_whitelist,
      # Issue#82 Add in the correct place other redirect configs that we may
      # wish (e.g. replacements)
      $redirects_external_prevented_adhoc_config,
      [ "proxy_redirect ~.* /${redirects_external_location};" ],
    )
  } else {
    $redirects_external_location_ensure = 'absent'
    $redirects_external_prevent_config = []
  }
  $redirects_external_location_hash = {
    "https_www.${domain}_${redirects_external_location}" => {
      ensure   => $redirects_external_location_ensure,
      location => "/${redirects_external_location}",
      server   => "https_www.${domain}",
      location_allow => $allow,
      location_deny => $deny,
      # The "return" below ignores the location_allow and location_deny above.
      # This happens because nginx processes requests in phases, and the
      # rewrite phase (return) goes before the access phase (allow/deny).
      # http://www.nginxguts.com/2011/01/phases/
      # At this moment it's not a problem because both return a 403.
      # The location_allow and location_deny are kept in case the code below
      # changes from a return to a webpage (i.e. a custom error page)
      # in which case the 403 code will come from the deny directive.
      location_custom_cfg_prepend => {'return' => '403;',}
    }
  }

  # choose to set or not backend variable
  if $dynamic_dns_resolution {

    $backend_reconstructed_upstreams = $nginx_upstream_members.reduce([]) | $previous_list, $item | {
      $tmp_server = $item[1][server]
      $tmp_port = $item[1][port]
      $previous_list + [ "${tmp_server}:${tmp_port}" ]
    }
    $server_cfg_prepend = { 'set' => "\$proxy_backend ${backend_protocol}://${backend_reconstructed_upstreams[0]}" }

  }
  else {
      $server_cfg_prepend = undef

      # Issue#16:
      # As least for now it seems we want to prevent setting up two
      # frontends for the same domain, so to avoid that we use
      # the domain in the resource names (and not e.g. the title)
      # so that we get a duplicate declaration in such cases
      $backend_name = "backend_${domain}";
      nginx::resource::upstream { $backend_name:
          ensure  => $servers_ensure,
          members => $nginx_upstream_members, # this variable is generated in the beggining of the class to convert old sintax to new sintax
      }
  }

  if $enable_ssl {
    if ( $decorate_naked == true ) {
      $naked_str = "301 https://www.${domain}\$request_uri"
    }
    else {
      $naked_str = "301 https://${domain}\$request_uri"
    }

    # the naked domain server redirects depending on the decorate_naked variable
    nginx::resource::server { "http_${domain}":
      ensure              => $servers_ensure,
      server_name         => [ $domain ],
      listen_port         => 80,
      location_allow      => $allow,
      location_deny       => $deny,
      ssl                 => false,
      location_custom_cfg => {
        'return' => $naked_str,
      }
    }
  }

  # the http www server redirects to https server
  # For this one we need to parse two flags
  if $enable_ssl {
    if ( $servers_create and $redirect_http_www_to_https_www_create ) {
      $redirect_http_www_to_https_www_ensure = 'present'
    } else {
      $redirect_http_www_to_https_www_ensure = 'absent'
    }
    nginx::resource::server { "http_www.${domain}":
      ensure              => $redirect_http_www_to_https_www_ensure,
      server_name         => [ "www.${domain}"],
      listen_port         => 80,
      location_allow      => $allow,
      location_deny       => $deny,
      ssl                 => false,
      location_custom_cfg => {
        'return' => "301 https://www.${domain}\$request_uri",
      }
    }
  }

  # workaround backends that send plain http redirects to the already suffixed
  # URL. we have a handler that adds the 's' to the redirection http and
  # discounts the suffix when connecting to the backend
  if ( $www_fix_redirect == true ) {
    $www_redir_str = 'http://$host/ https://$host/'
    nginx::resource::location { "www-catcher_${domain}":
      ensure                => present,
      server                => "https_www.${domain}",
      # both ssl settings necessary or this location falls out of place on the
      # file
      ssl                   => true,
      ssl_only              => true,
      location              => "~ /${domain_backend_pass_suffix}",
      location_allow        => $allow,
      location_deny         => $deny,
      proxy_set_header      => $domain_backend_set_headers,
      proxy_redirect        => $www_redir_str,
      proxy                 => "http://${backend_name}",
      # Issue #292
      proxy_read_timeout    => $proxy_read_timeout,
      proxy_connect_timeout => $proxy_connect_timeout,
      proxy_send_timeout    => $proxy_send_timeout,
    }
  }
  else {
    if ( $dynamic_dns_resolution ) {
        # this redirect was causing issues so setting it to
        # / / makes it do nothing, which is needed in this case
        $www_redir_str = "/ /"
    }
    else {
        $www_redir_str = 'default'
    }
  }

  if $enable_ssl {
    if ( $decorate_naked == true ) {
      # separate ssl server just for redirection of naked ssl requests
      nginx::resource::server { "https_${domain}":
        ensure                    => $servers_ensure,
        require                   => Puppet_infrastructure::Ssl_nginx_domain[$frontend_sslprefix],
        server_name               => [ $domain ],
        listen_port               => 443,
        location_allow            => $allow,
        location_deny             => $deny,
        ssl                       => true,
        ssl_port                  => 443,
        ssl_cert                  => $ssl_cert_path,
        ssl_key                   => $ssl_key_path,
        ssl_protocols             => $base_ssl_protocols,
        ssl_ciphers               => $base_ssl_ciphers,
        ssl_prefer_server_ciphers => $base_ssl_prefer_server_ciphers,
        ssl_dhparam               => $base_dh_params,
        server_cfg_ssl_append     => {
          'ssl_ecdh_curve' => $base_ssl_ecdh_curve,
        },
        proxy_set_header          => $domain_backend_set_headers,
        location_custom_cfg       => {
          'return' => "301 https://www.${domain}\$request_uri",
        },
      }
      $domain_list = [ "www.${domain}" ]
    }
    else {
      if ($server_https_www_create) {
        $domain_list = [ $domain, "www.${domain}" ]
      } else {
        $domain_list = [ $domain, ]
      }
      nginx::resource::server { "https_${domain}":
        # Notice the next ensure is to remove the above server
        # when the $decorate_naked changes to false
        # so we want it set to 'absent' and not to $servers_ensure
        # because $servers_create might be true and $decorate_naked false
        ensure         => absent,
        server_name    => [ $domain ],
        location_allow => $allow,
        location_deny  => $deny,
      }
    }
  } else {
    $domain_list = [$domain]
  }

  # Issue#82 The variable $proxy_locations_raw_append is an array-of-strings
  # that joins the $redirects_external_prevent_config array
  # and the $proxy_locations_adhoc_configs array
  # (where you can pass e.g. subs_filter_types and subs_filter directives)
  # to be used for the main location
  # (you can easily use this to extend for further raw configs by joining
  # further arrays)
  $proxy_locations_raw_append = $redirects_external_prevent_config + $proxy_locations_adhoc_config

  # we need to set a unique name for the root location, because
  # even if a location is a defined type we need to prevent a duplicate name
  $name_location_root = "https_www.${domain}_root"

  # We don't want a trailing slash in backend_name when we are not using the
  # domain_backend_pass_suffix because that means location statements would need
  # to add the location in the proxy_pass directive. So we write a case to take
  # that into account:
  if $domain_backend_pass_suffix == '' {
    if $dynamic_dns_resolution {
      $proxy_value = '$proxy_backend'
    }
    else {
      $proxy_value = "${backend_protocol}://${backend_name}"
    }
  }
  else {
    $proxy_value = "${backend_protocol}://${backend_name}/${domain_backend_pass_suffix}"
  }
  # our base_location hash has the parameters always used in the root location
  # (i.e. both with and without security headers)
  $base_location = {
    # we need to set the location here as a parameter
    # instead of reading from the name
    # so that we prevent a duplicate name
    location => '/',
    proxy => $proxy_value,
    proxy_redirect => $www_redir_str,
    proxy_set_header => $domain_backend_set_headers,
    # Issue#82 We pass down the array-of-strings $proxy_locations_ignore_headers
    # as a proxy_ignore_header parameter (beware the obfuscated singular and
    # plural:
    # the proxy_ignore_header puppet-nginx parameter takes multiple headers (in
    # an array) and declares a proxy_ignore_headers nginx directive for each one
    proxy_ignore_header => $proxy_locations_ignore_headers,
    # Issue#31 this won't add anything if the list of raw configs is empty
    # Issue#82 Pass down our compilation of raw configs
    raw_append => $proxy_locations_raw_append,
    location_allow => $allow,
    location_deny  => $deny,
    # Issue #286
    proxy_read_timeout => $proxy_read_timeout,
    proxy_connect_timeout => $proxy_connect_timeout,
    proxy_send_timeout => $proxy_send_timeout,
  }
  # Beware $mylocations contains our root location and only that.
  # If we want the security headers we add parameters for that.
  if ( $security_headers == true ) {
    $mylocations = {
      $name_location_root => $base_location + {
          # While working on issue #121 we noticed we don't need to set the
          # server parameter here because we're passing this to a server
          # declaration and the puppet module will add the server as seen here:
          # https://github.com/voxpupuli/puppet-nginx/blob/300d3605e2b3d71e2a95a1dfd400e4b7cb203464/manifests/resource/server.pp#L467
        add_header => {
          'X-Frame-Options'           => $x_frame_options_value,
          'X-Content-Type-Options'    => 'nosniff',
          'X-XSS-Protection'          => '1; mode=block',
          'Strict-Transport-Security' => 'max-age=31536000; includeSubdomains',
        }
      }
    }
  }
  # in the other case we just take the other parameters
  else {
    $mylocations = { $name_location_root => $base_location }
  }

  # Issue #121
  # Configuring other locations (4 Steps)

  # Step 1 - For each hash in the array, parse the raw_append variable to
  # prepend the raw_append of the root location
  # Recall "If you try to access a nonexistent key from a hash, its value will
  # be undef."
  # Ref: https://puppet.com/docs/puppet/5.3/lang_data_hash.html#accessing-values
  $proxy_locations_others_config_raw_append_parsed = $proxy_locations_others_config.map |$hash| {
    if ($hash['raw_append'] == undef) {
      $hash
    } else {
      merge(
        $hash,
        { 'raw_append' => concat($mylocations["${name_location_root}"]['raw_append'], $hash['raw_append']) },
      )
    }
  }
  # Step 2 - Again for each hash in the array, add any parameters from
  # my_locations (those of the hashes in the array prevail)
  $proxy_locations_others_config_merged = $proxy_locations_others_config_raw_append_parsed.map |$hash| {
    merge(
      $mylocations["${name_location_root}"],
      $hash,
    )
  }
  # Step 3 - Prepare to convert the array of hashes into an hash of hashes
  # We need to convert the obtained configs for locations into an hash-of-hashes
  # because the create_resources function (used under the hood by the nginx
  # module) expects an hash. But the map function always returns an array. So to
  # convert the obtained configs into an hash, we first get an array of arrays
  # suitable for that, i.e. in the format [ [key, value], ... ] (in our case
  # value is the hash with the configs)
  $proxy_locations_others_config_with_keys = $proxy_locations_others_config_merged.map |$hash| {
    ["https_www.${domain}_${hash['location']}", $hash]
  }
  # Step 4 - We can now easily convert the array into an hash
  # Reference: https://puppet.com/docs/puppet/5.3/function.html#conversion-to-hash-and-struct
  $proxy_locations_others_config_parsed = Hash($proxy_locations_others_config_with_keys)

  # the 'main' log format inclues information about upstream
  if ( $use_compact_log_format ) {
    # our custom log format with upstream status
    $my_format_log = 'compact'
  } else {
    # default nginx value for log format
    $my_format_log = 'combined'
  }
  # main server which according to $domain_list
  # may or not serve wwww.$domain requests and
  # may or not serve $domain requests
  # Issue #143 There's no $location_allow or $location_deny here because
  # we don't use the default location and that's the location they would affect,
  # those parameters are inside $base_location
  if $enable_ssl {
    $http_protocol = 'https'
    $listen_port = 443
    $ssl = true
    $server_require = Puppet_infrastructure::Ssl_nginx_domain[$frontend_sslprefix]
  } else {
    $http_protocol = 'http'
    $listen_port = 80
    $ssl = false
    $server_require = []
  }
  nginx::resource::server { "${http_protocol}_www.${domain}":
    ensure                    => $servers_ensure,
    require                   => $server_require,
    server_name               => $domain_list,
    listen_port               => $listen_port,
    ssl                       => $ssl,
    ssl_port                  => 443,
    ssl_cert                  => $ssl_cert_path,
    ssl_key                   => $ssl_key_path,
    # log upstream stats
    format_log                => $my_format_log,
    ssl_protocols             => $base_ssl_protocols,
    ssl_ciphers               => $base_ssl_ciphers,
    ssl_prefer_server_ciphers => $base_ssl_prefer_server_ciphers,
    ssl_dhparam               => $base_dh_params,
    server_cfg_ssl_append     => {
      'ssl_ecdh_curve' => $base_ssl_ecdh_curve,
    },
    use_default_location      => false,
    # Issue#31 We want the external redirects location to be removed if we
    # change the corresponding variable, so we always want it in locations, with
    # ensuring present/absent as appropriate. If by accident we set the root
    # location in an ad-hoc location config, that will be ignored, as from the
    # sdtlib docs: "When there is a duplicate key, the key in the rightmost hash
    # takes precedence."
    locations                 => merge($redirects_external_location_hash, $proxy_locations_others_config_parsed, $mylocations, ),
    resolver                  => $resolver,
    server_cfg_prepend        => $server_cfg_prepend,
  }

}
