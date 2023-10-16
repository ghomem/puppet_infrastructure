### Purpose ########
# Parametrized class for postfix to allow email sending from any non specialized node, by mean of a relayhost.
class puppet_infrastructure::postfix_smtp_node (
  ) {

  $relayhost  = lookup('postfix_smtp_node::relayhost')
  $relayport  = lookup('postfix_smtp_node::relayport')
  $myorigin   = lookup( [ "${clientcert}::postfix_smtp_node::myorigin",  'postfix_smtp_node::myorigin'  ] )
  $mynetworks = lookup({ name => "${clientcert}::postfix_smtp_node::mynetworks", default_value => '127.0.0.0/8' })
  $mydestination = lookup( { name => [ "${clientcert}::postfix_smtp_node::mydestination",  'postfix_smtp_node::mydestination'  ] ,
                            default_value => $hostname })
  $message_size_limit = lookup( { name => [ "${clientcert}::postfix_smtp_node::message_size_limit",  'postfix_smtp_node::message_size_limit'  ] ,
                            default_value => '10240000' })
  $root_email_alias = lookup({ name => "${clientcert}::postfix_smtp_node::root_email_alias", default_value => '' })

  # strictly node specific
  $relayuser  = lookup("${clientcert}::postfix_smtp_node::relayuser")
  $relaypass  = lookup("${clientcert}::postfix_smtp_node::relaypass")


  # The file for postfix to use with the "CA certificates of root CAs trusted"
  # (http://www.postfix.org/postconf.5.html#smtp_tls_CAfile)
  # is different when using CentOS
  case $::osfamily {
      'RedHat': {
        $smtp_tls_CAfile = '/etc/ssl/certs/ca-bundle.crt'
        $cyrus_sasl_package = 'cyrus-sasl-plain'
      }
      default: {
        $smtp_tls_CAfile = '/etc/ssl/certs/ca-certificates.crt'
        $cyrus_sasl_package = 'libsasl2-modules'
      }
  }

  # Install cyrus SASL
  package { 'cyrus_sasl_package':
    ensure => installed,
    name   => $cyrus_sasl_package,
    notify => Service['postfix'],
  }

  file { '/etc/postfix/main.cf':
    mode      => '0644',
    owner     => 'root',
    group     => 'root',
    content   => template('puppet_infrastructure/postfix_smtp_node/main.cf'),
    subscribe => Package['postfix'],
    notify    => Service['postfix'],
  }

  file { '/etc/postfix/sasl_passwd':
    mode      => '0640',
    owner     => 'root',
    group     => 'root',
    content   => template('puppet_infrastructure/postfix_smtp_node/sasl_passwd'),
    subscribe => Package['postfix'],
    notify    => Exec['postmap_sasl'],
  }

  exec { 'postmap_sasl':
    command     => 'postmap /etc/postfix/sasl_passwd',
    refreshonly => true,
    user        => 'root',
    path        => [ '/usr/sbin/', '/bin/', '/usr/bin/' ],
    notify      => Service['postfix'],
  }

  service { 'postfix':
    ensure    => running,
    enable    => true,
    subscribe => Package['postfix'],
  }

  package { 'postfix':
    ensure => present,
  }

  file { '/etc/aliases':
    mode      => '0644',
    owner     => 'root',
    group     => 'root',
    content   => template('puppet_infrastructure/postfix_smtp_node/aliases'),
    subscribe => Package['postfix'],
    notify    => Exec['newaliases'],
  }

  exec { 'newaliases':
    command     => 'newaliases',
    refreshonly => true,
    user        => 'root',
    path        => [ '/usr/sbin/', '/bin/', '/usr/bin/' ],
    notify      => Service['postfix'],
  }

}
