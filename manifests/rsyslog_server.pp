class puppet_infrastructure::rsyslog_server (
  Integer $port     = 6514,
  String  $log_root = '/var/log',
) {

  include puppet_infrastructure::rsyslog_base

  $certname = $trusted['certname']

  file { '/etc/rsyslog.d/30-listener.conf':
    content => epp('puppet_infrastructure/rsyslog/listener_simple.conf.epp', {
      port     => $port,
      certname => $certname,
      log_root => $log_root,
    }),
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    notify => Service['rsyslog'],
  }

  # self-forwarding removed on purpose to avoid recursive logging loops
  file { '/etc/rsyslog.d/40-forward-self.conf':
    ensure => absent,
    notify => Service['rsyslog'],
  }

}
