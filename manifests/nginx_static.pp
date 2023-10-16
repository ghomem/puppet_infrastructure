### Purpose ########
# Our nginx static class does two things:
# - it installs nginx servers for the given domain (using our defined type
# nginx_static_domain);
# - it bundles the needed certificates (using our class ssl_nginx);
### Outputs ########
# - configured and running nginx servers
# - the bundled certificate and key are placed in (see our ssl_nginx class)
#   "${ssl_certs_dir}/${domain}.nginx.bundle.crt",
#   "${ssl_private_dir}/${domain}.key",
# For more documentation, read the comments in nginx_static_domain, nginx_frontend and nginx_frontend_domain
# and the wiki: https://bitbucket.org/asolidodev/puppet_infrastructure/wiki/NGINX%20Static%20server
class puppet_infrastructure::nginx_static (
  # These are the same parameters as those of our defined type nginx_static_domain,
  # so the explanation is given there. 
  String $domain,
  String $www_root,
  Boolean $servers_create          = true,
  String $static_sslprefix         = '',
  Boolean $manage_ssl              = false,
  Boolean $ssl                     = false,
  Boolean $letsencrypt_certificate = false,
  Boolean $redirect_to_https       = false,
  Boolean $redirect_to_www         = false,
  # $server_default_create is true by default here but
  # false by default in nginx_static_domain to maintain
  # a similar usability to nginx_frontend and nginx_frontend_domain
  Boolean $server_default_create   = true,
  Boolean $redirect_default        = false,
  Boolean $allow_directory_listing = false,
  Array $additional_ssl_protocols  = [],
  Array $additional_ssl_ciphers    = [],
  Array $base_ssl_protocols_prefix = ['TLSv1.2', ],
  String $base_ssl_ciphers_prefix  = 'DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384',
  String $base_ssl_ciphers_suffix  = '!DSS:!EXPORT',
  String $base_ssl_ecdh_curve      = 'prime256v1',
  Array $ip_whitelist              = [],
  # be careful not to override other configs from the class and don't forget the
  # semicolon ";" in direct nginx configs
  Hash $adhoc_configs              = {},
  Integer $http_port               = 80,
  Integer $https_port              = 443,
) {

  # includes the nginx_base class, can get overriden
  require Class[ 'puppet_infrastructure::nginx_base' ]

  # This removes the default nginx config file from the package
  include puppet_infrastructure::nginx_default_removal

  puppet_infrastructure::nginx_static_domain { $domain:
    domain                    => $domain,
    www_root                  => $www_root,
    static_sslprefix          => $static_sslprefix,
    manage_ssl                => $manage_ssl,
    ssl                       => $ssl,
    letsencrypt_certificate   => $letsencrypt_certificate,
    redirect_to_https         => $redirect_to_https,
    redirect_to_www           => $redirect_to_www,
    server_default_create     => $server_default_create,
    redirect_default          => $redirect_default,
    allow_directory_listing   => $allow_directory_listing,
    additional_ssl_protocols  => $additional_ssl_protocols,
    additional_ssl_ciphers    => $additional_ssl_ciphers,
    base_ssl_protocols_prefix => $base_ssl_protocols_prefix,
    base_ssl_ciphers_prefix   => $base_ssl_ciphers_prefix,
    base_ssl_ciphers_suffix   => $base_ssl_ciphers_suffix,
    base_ssl_ecdh_curve       => $base_ssl_ecdh_curve,
    ip_whitelist              => $ip_whitelist,
    servers_create            => $servers_create,
    adhoc_configs             => $adhoc_configs,
    http_port                 => $http_port,
    https_port                => $https_port,
  }

}
