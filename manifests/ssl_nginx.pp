### Purpose ########
# class to control ssl cert and key for nginx
class puppet_infrastructure::ssl_nginx (
  String $sslprefix
)
{

  puppet_infrastructure::ssl_base { 'puppet_infrastructure::ssl_base_nginx':
    myprefix      => $sslprefix,
    myservice     => 'nginx',
    myservicename => 'nginx'
  }

}
