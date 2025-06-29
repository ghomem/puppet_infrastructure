class puppet_infrastructure::rsyslog_client (
  String  $target,
  String  $target_ip,
  Integer $port         = 6514,
  Boolean $check_names  = false,   # true → require hostname == cert CN
  Optional[String] $failover      = undef,
  Optional[String]  $failover_ip = undef,
) {

  include puppet_infrastructure::rsyslog_base

  $certname = $trusted['certname']

  # guarantee the name is always resolvable
  if $target_ip {
    host { $target:
      ip     => $target_ip,
      target => '/etc/hosts',
    }
  }

  if $failover {
    if $failover_ip {
      host { $failover:
        ip     => $failover_ip,
        target => '/etc/hosts',
      }
    }
  }

  file { '/etc/rsyslog.d/40-forward.conf':
    content => epp('puppet_infrastructure/rsyslog/forward_simple.conf.epp', {
      target       => $target,
      port         => $port,
      certname     => $certname,
      check_names  => $check_names,
      failover     => $failover,
    }),
    owner  => 'root', group => 'root', mode => '0644',
    notify => Service['rsyslog'],
  }
}

