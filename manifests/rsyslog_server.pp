# TLS listener on port 6514.  No self-forward by default.
class puppet_infrastructure::rsyslog_server (
  Integer $port           = 6514,
  Boolean $self_forward   = false,
  String  $log_root      = '/var/log',
) {

  include puppet_infrastructure::rsyslog_base

  $certname = $trusted['certname']

  file { '/etc/rsyslog.d/30-listener.conf':
    content => epp('puppet_infrastructure/rsyslog/listener_simple.conf.epp', {
      port      => $port,
      certname  => $certname,
      log_root  => $log_root,
    }),
    owner   => 'root', group => 'root', mode => '0644',
    notify  => Service['rsyslog'],
  }

  if $self_forward {
    file { '/etc/rsyslog.d/40-forward-self.conf':
      content => epp('puppet_infrastructure/rsyslog/forward_simple.conf.epp', {
        target       => $certname,      # loopback
        port         => $port,
        certname     => $certname,
        check_names  => false,          # certvalid avoids CN==localhost issue
      }),
      owner  => 'root', group => 'root', mode => '0644',
      notify => Service['rsyslog'],
    }
  }
}

