class puppet_infrastructure::rsyslog_server (
  Integer $port          = 6514,
  Boolean $self_forward  = true,
) {

  include puppet_infrastructure::rsyslog_base

  $ssldir   = "/etc/rsyslog.d/tls"

  $ca_file   = "${ssldir}/ca.pem"
  $cert_file = "${ssldir}/${facts['fqdn']}.crt"
  $key_file  = "${ssldir}/${facts['fqdn']}.key"

  file { '/etc/rsyslog.d/30-listener.conf':
    mode    => '0644',
    content => epp('puppet_infrastructure/rsyslog/listener_simple.conf.epp', {
                    port      => $port,
                    ca_file   => $ca_file,
                    cert_file => $cert_file,
                    key_file  => $key_file,
                  }),
    notify  => Service['rsyslog'],
  }

  if $self_forward {
    file { '/etc/rsyslog.d/40-forward-self.conf':
      mode    => '0644',
      content => epp('puppet_infrastructure/rsyslog/forward_simple.conf.epp', {
                      target       => $facts['fqdn'],
                      ca_file      => $ca_file,
                      cert_file    => $cert_file,
                      key_file     => $key_file,
                      port         => $port,
                      use_failover => false,
                      failover     => undef,
                    }),
      notify  => Service['rsyslog'],
    }
  }

  firewall { '200 accept rsyslog connections': proto  => 'tcp', dport  => 6514, action => 'accept', }

}
