class puppet_infrastructure::rsyslog_client (
  String  $target,
  Integer $port         = 6514,
  Boolean $use_failover = false,
  Optional[String] $failover = undef,
) {

  include puppet_infrastructure::rsyslog_basics

  $ca_file   = '/etc/puppetlabs/puppet/ssl/certs/ca.pem'
  $cert_file = "/etc/puppetlabs/puppet/ssl/certs/${facts['fqdn']}.pem"
  $key_file  = "/etc/puppetlabs/puppet/ssl/private_keys/${facts['fqdn']}.pem"

  file { '/etc/rsyslog.d/40-forward.conf':
    mode    => '0644',
    content => epp('puppet_infrastructure/rsyslog/forward_simple.conf.epp', {
                    target       => $target,
                    failover     => $failover,
                    use_failover => $use_failover,
                    ca_file      => $ca_file,
                    cert_file    => $cert_file,
                    key_file     => $key_file,
                    port         => $port,
                  }),
    notify  => Service['rsyslog'],
  }
}
