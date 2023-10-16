### Purpose ########
# class to control ssl cert and key for postfix
class puppet_infrastructure::ssl_postfix (
  String $sslprefix,
  Boolean $letsencrypt_certificate,
){
  puppet_infrastructure::ssl_base { 'postfix ssl config':
    myprefix                => $sslprefix,
    myservice               => 'postfix',
    myservicename           => 'postfix',
    letsencrypt_certificate => $letsencrypt_certificate,
  }
}
