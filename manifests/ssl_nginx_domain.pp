### Purpose ########
# defined type to control ssl cert and key for nginx
define puppet_infrastructure::ssl_nginx_domain (
  String $sslprefix,
  Boolean $letsencrypt_certificate = false,
)
{

  puppet_infrastructure::ssl_base { "ssl_${sslprefix}":
    myprefix                => $sslprefix,
    myservice               => 'nginx',
    myservicename           => 'nginx',
    letsencrypt_certificate => $letsencrypt_certificate,
  }

}
