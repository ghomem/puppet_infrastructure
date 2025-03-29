### Purpose ########
# This defined type is used by our classes which control the deploy
# of ssl certs and keys for different types of services in different distributions
### Outputs ########
# The key file is placed in the node in:
#   ${ssl_private/dir}/${myprefix}.key
# The certificate is formated and/or bundled as needed by
# the service and it is placed in the node in:
#   ${ssl_certs_dir}/${myprefix}.${myservice}.bundle.crt
# The service is restarted if the certificate changes.
### Inputs ########
# Strings:
#   see below the class parameters
# Files:
#   certificate key to be found in master at:
#     puppet:///extra_files/ssl/${myprefix}.key
#   certificate to be found in master at:
#     puppet:///extra_files/ssl/${myprefix}.crt
#   intermediate certificates to be found in master at:
#     puppet:///extra_files/ssl/${myprefix}.intermediate.crt
### Environment ####
# OS: ubuntu 16.04 (nginx and postfix), CentOS 7 (nginx)
define puppet_infrastructure::ssl_base (
  # For each parameter we set the Data Type (so that we get and error if there is an unexpected data type as input)
  # We also avoid setting a default such as "" (so that we avoid doing anything if the mandatory inputs are not given)

  # This argument identifies the certificate's scope and is expected in the (private) key file:
  # "${myprefix}.key"
  # and in the (public) unbundled certificate:
  # "${myprefix}.crt"
  String $myprefix,

  # The is the name we give to the service across linux distributions
  # This will be placed into the (bundled) cert file that will be created in the node
  # "${myprefix}.${myservice}.bundle.crt"
  String $myservice,

  # This is the name of the service to be restarted on cert changes
  # (because it depends on the distribution, e.g. for apache)
  String $myservicename,

  # This argument defines whether we are using a letsencrypt certificate or not
  # as their certificate termination differs from our self managed certificates
  Boolean $letsencrypt_certificate = false,
) {

  # Notice we do not manage the '/etc/ssl/private/' directory here
  # because this defined type may be declared multiple times for a same node

  # We're moving on to support RedHat family also
  case $facts['os']['family'] {
    'RedHat': {
      $ssl_private_dir = '/etc/pki/tls/private'
      # In RedHat family there is a link pointing this directory to /etc/pki/tls/certs so we can use that
      $ssl_certs_dir  = '/etc/ssl/certs'
    }
    # We consider Ubuntu be our default OS ('Debian' family)
    default:  {
      $ssl_private_dir = '/etc/ssl/private'
      $ssl_certs_dir  = '/etc/ssl/certs'
    }
  }

  if $letsencrypt_certificate {
    $key_file                 = "${ssl_private_dir}/${myprefix}-key.pem"
    $key_source               = "puppet:///extra_files/ssl/${myprefix}-key.pem"
    $bundle_file              = "${ssl_certs_dir}/${myprefix}.${myservice}.bundle.pem"
    $first_cert_source        = "puppet:///extra_files/ssl/${myprefix}.pem"
    $intermediate_cert_source = "puppet:///extra_files/ssl/${myprefix}-chain.pem"
  } else {
    $key_file                 = "${ssl_private_dir}/${myprefix}.key"
    $key_source               = "puppet:///extra_files/ssl/${myprefix}.key"
    $bundle_file              = "${ssl_certs_dir}/${myprefix}.${myservice}.bundle.crt"
    $first_cert_source        = "puppet:///extra_files/ssl/${myprefix}.crt"
    $intermediate_cert_source = "puppet:///extra_files/ssl/${myprefix}.intermediate.crt"
  }

  # Key file: always created, always notifies service
  file { $key_file:
    ensure => present,
    notify => Service[$myservicename],
    mode   => '0600',
    owner  => 'root',
    group  => 'root',
    source => $key_source,
  }

  # If the service is not one of the “known” ones, log a warning rather than fail.
    unless $myservice in ['nginx','postfix'] {
    notify { 'WARNING: puppet_infrastructure::ssl_base: Externally managed service "${myservice}" will be notified.': withpath => false }
  }

  # Always do the bundling
  concat { $bundle_file:
    ensure         => present,
    notify         => Service[$myservicename],
    mode           => '0644',
    owner          => 'root',
    group          => 'root',
    ensure_newline => true,
  }

  concat::fragment { "first_certificate_${myprefix}":
    target => $bundle_file,
    order  => '01',
    source => $first_cert_source,
  }

  concat::fragment { "intermediate_certificates_${myprefix}":
    target => $bundle_file,
    order  => '02',
    source => $intermediate_cert_source,
  }
}
