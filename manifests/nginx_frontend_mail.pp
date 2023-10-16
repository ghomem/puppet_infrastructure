### PURPOSE ########
# This class sets up mail reverse proxy with the following ports and protocols (by default):
# - port 993: imap with ssl
# - port 465: smpt with ssl
# - port 25: smtp
# 
# In this setup, we have 3 mailhost servers (one for each of the protocols above),
# 4 http server blocks (one that proxies the request to the backend web interface by using the nginx_frontend_domain class,
# and the other three are to set up the authentication on the backend by using the nginx::resource::server defined type)
# and three stream servers (that will, effectively, pass the authentication to the backend,
# for that we used the nginx::resource::streamhost)

class puppet_infrastructure::nginx_frontend_mail (
  String $domain,
  String $mail_backend,
  $frontend_sslprefix,
  $smtp_helo = $domain,
  Boolean $letsencrypt_certificate,
  Boolean $proxy_ssl_verify = false,
  Integer $https_port = 443,
  Integer $imaps_port = 993,
  Integer $smtps_port = 465,
  Integer $smtp_port = 25,
){

  puppet_infrastructure::ssl_nginx_domain { $frontend_sslprefix:
    sslprefix               => $frontend_sslprefix,
    letsencrypt_certificate => $letsencrypt_certificate,
  }

  if ( $letsencrypt_certificate ) {
    $ssl_cert_path = "/etc/ssl/certs/${frontend_sslprefix}.nginx.bundle.pem"
    $ssl_key_path = "/etc/ssl/private/${frontend_sslprefix}-key.pem"
  } else {
    $ssl_cert_path = "/etc/ssl/certs/${frontend_sslprefix}.nginx.bundle.crt"
    $ssl_key_path = "/etc/ssl/private/${frontend_sslprefix}.key"
  }

  if ( $proxy_ssl_verify ) {
    $ssl_verify = 'on'
  } else {
    $ssl_verify = 'off'
  }

  puppet_infrastructure::nginx_frontend_domain { $domain:
    domain                  => $domain,
    frontend_sslprefix      => $frontend_sslprefix,
    backend_hosts_and_ports => ["${mail_backend}:${https_port}", ],
    backend_protocol        => 'https',
    letsencrypt_certificate => true,
    manage_ssl              => false,
  }

  nginx::resource::mailhost { "imaps_${domain}":
    auth_http                => 'localhost:4242/auth',
    protocol                 => 'imap',
    listen_port              => $imaps_port,
    xclient                  => 'off',
    proxy_pass_error_message => 'on',
    imap_auth                => 'login plain',
    ssl_port                 => $imaps_port,
    ssl                      => true,
    ssl_cert                 => $ssl_cert_path,
    ssl_key                  => $ssl_key_path,
  }

  nginx::resource::mailhost { "smtps_${domain}":
    auth_http                => 'localhost:4243/auth',
    protocol                 => 'smtp',
    listen_port              => $smtps_port,
    xclient                  => 'off',
    proxy_pass_error_message => 'on',
    smtp_auth                => 'login plain',
    ssl_port                 => $smtps_port,
    ssl                      => true,
    ssl_cert                 => $ssl_cert_path,
    ssl_key                  => $ssl_key_path,
    raw_prepend              => [
      'proxy_smtp_auth          on;',
    ],
  }

  nginx::resource::mailhost { $smtp_helo:
    auth_http                => 'localhost:4244/auth',
    xclient                  => 'off',
    protocol                 => 'smtp',
    listen_port              => $smtp_port,
    smtp_auth                => 'none',
    proxy_pass_error_message => 'on',
    ssl                      => false,
    raw_prepend              => [
      'proxy_smtp_auth          off;',
    ],
  }

  nginx::resource::streamhost { 'imap_auth_stream':
    ensure      => present,
    proxy       => "${mail_backend}:${imaps_port}",
    listen_port => 9993,
    raw_append  => [
      'proxy_ssl        on;',
      "proxy_ssl_verify ${ssl_verify};",
    ],
  }

  nginx::resource::streamhost { 'smtps_auth_stream':
    ensure      => present,
    proxy       => "${mail_backend}:${smtps_port}",
    listen_port => 9465,
    raw_append  => [
      'proxy_ssl        on;',
      "proxy_ssl_verify ${ssl_verify};",
    ],
  }

  nginx::resource::streamhost { 'smtp_auth_stream':
    ensure      => present,
    proxy       => "${mail_backend}:${smtp_port}",
    listen_port => 9925,
    raw_append  => [
      'proxy_ssl        off;',
      "proxy_ssl_verify ${ssl_verify};",
    ],
  }

  nginx::resource::server { 'imap_auth_server':
    listen_port => 4242,
    raw_append  => [
      'location /auth {',
      '  add_header Auth-Status OK;',
      '  add_header Auth-Server 127.0.0.1;',
      '  add_header Auth-Port   9993;',
      '  return 204;',
      '}',
    ],
  }

  nginx::resource::server { 'smtps_auth_server':
    listen_port => 4243,
    raw_append  => [
      'location /auth {',
      '  add_header Auth-Status OK;',
      '  add_header Auth-Server 127.0.0.1;',
      '  add_header Auth-Port   9465;',
      '  return 204;',
      '}',
    ],
  }

  nginx::resource::server { 'smtp_auth_server':
    listen_port => 4244,
    raw_append  => [
      'location /auth {',
      '  add_header Auth-Status OK;',
      '  add_header Auth-Server 127.0.0.1;',
      '  add_header Auth-Port   9925;',
      '  return 204;',
      '}',
    ],
  }
}

