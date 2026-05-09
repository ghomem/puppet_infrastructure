# Configure a node to forward its local logs to a remote rsyslog server over TLS.

class puppet_infrastructure::rsyslog_client (
  String            $target,
  Optional[String]  $target_ip       = undef,
  Integer           $port            = 6514,
  Boolean           $check_names     = false,
  Optional[String]  $failover        = undef,
  Optional[String]  $failover_ip     = undef,
  Optional[String]  $ssldir_override = undef,
) {

  # Reuse the shared rsyslog setup; allow the SSL dir to be overridden when needed.

  class { 'puppet_infrastructure::rsyslog_base':
    ssldir_override => $ssldir_override,
  }

  $certname = $trusted['certname']

  # Only pin the target in /etc/hosts when an explicit IP is provided.

  if $target_ip != undef {
    host { $target:
      ip     => $target_ip,
      target => '/etc/hosts',
    }
  }

  # Do the same for the optional failover target.

  if $failover != undef and $failover_ip != undef {
    host { $failover:
      ip     => $failover_ip,
      target => '/etc/hosts',
    }
  }

  # Render the forwarding rule and restart rsyslog if it changes.

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
