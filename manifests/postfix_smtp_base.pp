### Purpose ########
# Setup a SMTP server with SSL and configurable restrictions
# - only certain IPs can use it
# - only certain users can use it (note: using own user database, separate from OS users)
# - only MAIL FROM in a configurable list can be used in general
# - and deach MAIL FROM can only be used by certain (configured) user(s)
### Warnings #######
# The general MAIL FROM list prevails. That is, if a user is allowed to use a MAIL FROM address
# but then that address is not in the general MAIL FROM list, then sending will NOT be allowed.
# A user can use any FROM address but a warning will be logged if
# the used FROM address is in a configurable list (common for all users).
### Justifications #
# As of today there are no supported nor approved puppet forge postfix modules
# There are only two modules with more than 25k downloads:
#  camptocamp/postfix
#  mjhas/postfix
# But community ratings are not high (respectively 3.1 and 3.6) and they do not support puppet 5.
# So we roll our own class for this.
class puppet_infrastructure::postfix_smtp_base (
  $smtp_hostname,
  $smtp_sslprefix,
  $postfix_port,
  $smtp_users = [],
  $allowed_client_ips= [],
  $allowed_mail_from_addresses= [],
  $allowed_users_per_mail_from_address = [],
  $do_not_warn_from_addresses_regexes = [],
  $extra_sec = false,
  $dh_params_bits = 2048, # "With Postfix ≥ 3.1 the out of the box (compiled-in) EDH prime size is 2048 bits." - we recreate using the same size
  Boolean $letsencrypt_certificate = false,

) {

  # Design pattern for resource relationships
  # For related package, config files and services, the relations are written as:
  # - config files subscribe to package
  # - config files notify service
  # - service subscribes to package
  # Because:
  # - it's less verbose (you don't need to re-write long resource names of config files relations)
  # - it's easier to mantain (you can add another config file and subscribe-notify without touching the other resources)
  # - it deals with updates (the service subscribes package means that the service will be restarted if the
  # package is updated, even if config files are not changed, or in case in the future they are all removed)

  ## Certificates
  # Install certificates
  class { 'puppet_infrastructure::ssl_postfix':
    sslprefix               => $smtp_sslprefix,
    letsencrypt_certificate => $letsencrypt_certificate,
  }

  # Set our auxiliary variables

  if ( $letsencrypt_certificate ) {
    $certificate_filename = "/etc/ssl/certs/${smtp_sslprefix}.postfix.bundle.pem"
    $key_filename = "/etc/ssl/private/${smtp_sslprefix}-key.pem"
  } else {
    $certificate_filename = "/etc/ssl/certs/${smtp_sslprefix}.postfix.bundle.crt"
    $key_filename = "/etc/ssl/private/${smtp_sslprefix}.key"
  }

  # create custom DH group
  $base_dh_params = '/etc/postfix/dhparams.pem'
  if ( $extra_sec == true ) {
    exec {"Generate a new postfix ${dh_params_bits}-bit Diffie-Hellman group":
      command => "/usr/bin/openssl dhparam -out ${base_dh_params} ${dh_params_bits} && chmod u=rw,g=r,o= ${base_dh_params}",
      creates => $base_dh_params,
    }
  }

  ## Packages

  # Ensure packages required for SMTP, testing and SASL authentication are installed
  package {[
    # To provide smtp server
    'postfix',
    # To provide mail
    'mailutils',
    # To enable Dovecot SASL the dovecot-core package will need to be installed.
    'dovecot-core',
    ]:
    ensure    => present,
  }

  ## SALS authentication (using Dovecot) for SMTP (using Postfix)

  # Declare Dovecot master config file to integrate with Postfix.
  # The original file is kept in files as '10-master.conf.original'.
  # Reference: http://www.postfix.org/SASL_README.html#server_dovecot
  file {'/etc/dovecot/conf.d/10-master.conf':
    ensure    => present,
    subscribe => Package['dovecot-core'],
    notify    => Service['dovecot'],
    source    => 'puppet:///modules/puppet_infrastructure/postfix_smtp_base/10-master.conf',
  }
  # Declare Dovecot authorization config file
  # The original file is kept in files as '10-auth.conf.original'.
  # It sets PLAIN and LOGIN as authentication mechanisms (as we're using SSL/TLS)
  # References:
  # http://www.postfix.org/SASL_README.html#server_dovecot
  # https://wiki2.dovecot.org/Authentication/Mechanisms
  # It also sets the authentication database
  # (by including auth-passwdfile.conf.ext)
  # to be a file similar to passwd with the CRYPT password scheme
  # and removes the Dovecot default unix user authentication.
  # References:
  # https://wiki2.dovecot.org/AuthDatabase/PasswdFile
  # https://wiki2.dovecot.org/Authentication/PasswordSchemes
  file {'/etc/dovecot/conf.d/10-auth.conf':
    ensure    => present,
    subscribe => Package['dovecot-core'],
    notify    => Service['dovecot'],
    source    => 'puppet:///modules/puppet_infrastructure/postfix_smtp_base/10-auth.conf',
  }

  # Declare Dovecot users file (usernames and password hashes).
  file { '/etc/dovecot/users':
    ensure    => present,
    subscribe => Package['dovecot-core'],
    notify    => Service['dovecot'],
    content   => template('puppet_infrastructure/postfix_smtp_base/sasl_users.erb'),
  }

  # Ensure dovecot service is running
  service {'dovecot':
    ensure    => running,
    subscribe => Package['dovecot-core'],
  }

  # Configure data source with the IPs allowed for SMTP clients
  puppet_infrastructure::postfix_smtp_base_config_file {'/etc/postfix/client_access':
  }

  # Configure data source with MAIL FROM addresses that are globally allowed
  puppet_infrastructure::postfix_smtp_base_config_file {'/etc/postfix/sender_access':
  }

  # Configure data source that sets which users can use which MAIL FROM addresses
  puppet_infrastructure::postfix_smtp_base_config_file {'/etc/postfix/controlled_envelope_senders':
  }

  # Configure postfix
  # The original file is kept in files as 'main.cf.original'.
  file { '/etc/postfix/main.cf':
    ensure    => present,
    subscribe => Package['postfix'],
    notify    => Service['postfix'],
    content   => template('puppet_infrastructure/postfix_smtp_base/main.cf.erb'),
    owner     => 'root',
    group     => 'root',
    mode      => 'u=rw,g=r,o=r',
  }

  # The original file is kept in files as 'main.cf.original'.
  file { '/etc/postfix/master.cf':
    ensure    => present,
    subscribe => Package['postfix'],
    notify    => Service['postfix'],
    content   => template('puppet_infrastructure/postfix_smtp_base/master.cf.erb'),
    owner     => 'root',
    group     => 'root',
    mode      => 'u=rw,g=r,o=r',
  }

  # File with the regex to for restrictions in the email
  file {'/etc/postfix/smtp_header_checks.regexp':
    ensure    => present,
    subscribe => Package['postfix'],
    notify    => Service['postfix'],
    content   => template('puppet_infrastructure/postfix_smtp_base/smtp_header_checks.regexp.erb'),
    # Ensure it's owned by root:root
    owner     => 'root',
    group     => 'root',
    # Ensure only root can write
    mode      => 'u=rw,g=r,o=r',
  }

  # Postfix service
  service {'postfix':
    ensure    => 'running',
    subscribe => [Package['postfix'], Service['dovecot'], ]
  }

}
