class puppet_infrastructure::rsyslog_client (
  String            $target,
  Optional[String]  $target_ip    = undef,
  Integer           $port         = 6514,
  Boolean           $check_names  = false,
  Optional[String]  $failover     = undef,
  Optional[String]  $failover_ip  = undef,
) {

  include puppet_infrastructure::rsyslog_base

  $certname = $trusted['certname']

  if $target_ip != undef {
    host { $target:
      ip     => $target_ip,
      target => '/etc/hosts',
    }
  }

  if $failover != undef and $failover_ip != undef {
    host { $failover:
      ip     => $failover_ip,
      target => '/etc/hosts',
    }
  }

  file { '/etc/rsyslog.d/40-forward.conf':
    content => epp('puppet_infrastructure/rsyslog/forward_simple.conf.epp', {
      target      => $target,
      port        => $port,
      certname    => $certname,
      check_names => $check_names,
      failover    => $failover,
    }),
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    notify => Service['rsyslog'],
  }
}
