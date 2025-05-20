class puppet_infrastructure::rsyslog_client (
  String  $target,
  Integer $port         = 6514,
  Boolean $use_failover = false,
  Optional[String] $failover = undef,
) {

  include puppet_infrastructure::rsyslog_base

  $ssldir   = "/etc/rsyslog.d/tls"

  $ca_file   = "${ssldir}/ca.pem"
  $cert_file = "${ssldir}/${facts['fqdn']}.pem"
  $key_file  = "${ssldir}/${facts['fqdn']}.pem"

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
