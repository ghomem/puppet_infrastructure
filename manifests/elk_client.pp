### Purpose ########
# This class sets up a client no connect to a ELK server (puppet_infrastructure::elk_server)

## For documentation please refer to:
# https://bitbucket.org/asolidodev/puppet_infrastructure/wiki/Class%20ELK%20(Server%20and%20client)

class puppet_infrastructure::elk_client (
  Boolean $fix_rsyslog_shutdown = false, # if true, fixes a shutdown delay of 1:30
) {

  if ( $::osfamily == 'RedHat' ) {

    group { 'syslog': ensure => 'present', gid => 0, allowdupe => true }
    user  { 'syslog': ensure => 'present', uid => 0, allowdupe => true }

  }

  package { 'rsyslog-gnutls': ensure => 'installed', }

  $is_client_staging     = lookup({ name => "${clientcert}::elk::client::is_client_staging", default_value => false })
  $use_rsyslog_failover  = lookup({ name => 'elk::server::cluster', default_value => false })

  if ( $is_client_staging == true ) {

    $ca_path          = 'puppet_infrastructure/elk/ca-staging.pem'
    $cert_client_path = 'puppet_infrastructure/elk/client-cert-staging.pem'
    $key_client_path  = 'puppet_infrastructure/elk/client-key-staging.pem'
    $server_node      = 'elk-staging'
    $elk_server       = 'logs-staging.angulosolido.pt'

  }
  else {

    $ca_path          = lookup( [ "${clientcert}::elk::ca_path", 'elk::ca_path' ] )
    $cert_client_path = lookup( [ "${clientcert}::elk::client::cert_client_path", 'elk::client::cert_client_path' ] )
    $key_client_path  = lookup( [ "${clientcert}::elk::client::key_client_path", 'elk::client::key_client_path' ] )
    $server_node      = lookup( [ "${clientcert}::elk::client::servernodename", 'elk::client::servernodename' ] )
    $elk_server       = lookup( [ "${server_node}::elk::server::elk_server", 'elk::server::elk_server' ] )

  }

  $elk_server_ip = lookup({ name => [ "${server_node}::elk::server::elk_server_ip", 'elk::server::elk_server_ip' ] })
  host { $elk_server:
    ip     => $elk_server_ip,
    notify => Service['rsyslog'],
  }

  if ( $use_rsyslog_failover ) {
    $elk_server_failover    = lookup({ name => [ "${server_node}::elk::server::elk_server_failover", 'elk::server::elk_server_failover' ] })
    $elk_server_failover_ip = lookup({ name => [ "${server_node}::elk::server::elk_server_failover_ip", 'elk::server::elk_server_failover_ip' ] })
    host { $elk_server_failover:
      ip     => $elk_server_failover_ip,
      notify => Service['rsyslog'],
    }
  }

  file { '/etc/ssl/logstash-ca.pem':
    notify  => Service['rsyslog'],
    mode    => '0600',
    owner   => 'syslog',
    group   => 'syslog',
    replace => 'yes',
    content => file($ca_path),
  }

  file { '/etc/ssl/logstash-client-cert.pem':
    notify  => Service['rsyslog'],
    mode    => '0600',
    owner   => 'syslog',
    group   => 'syslog',
    replace => 'yes',
    content => file($cert_client_path),
  }

  file { '/etc/ssl/logstash-client-key.pem':
    notify  => Service['rsyslog'],
    mode    => '0600',
    owner   => 'syslog',
    group   => 'syslog',
    replace => 'yes',
    content => file($key_client_path),
  }

    file { '/etc/rsyslog.d/40-elk.conf':
      ensure  => present,
      notify  => Service['rsyslog'],
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => template('puppet_infrastructure/elk/40-elk.conf.erb'),
    }

  if $fix_rsyslog_shutdown {

    # The 2 file resources below are to avoid a 1 min 30 secs waiting when shutting down the laptops, see:
    # - https://bugzilla.redhat.com/show_bug.cgi?id=1263853
    # - https://github.com/rsyslog/rsyslog/commit/cfd07503ba055100a84d75d1a78a5c6cceb9fdab
    #
    # To avoid the problem we both:
    # - set 'After=network.online' for rsyslog systemd service
    # - just in case we set a shorter timeout in case the process doesn't react to SIGTERM
    file { '/etc/systemd/system/rsyslog.service.d':
      ensure  => 'directory',
      mode    => '0755',
      owner   => 'root',
      group   => 'root',
    }

    include puppet_infrastructure::systemd_daemon_reload

    file { '/etc/systemd/system/rsyslog.service.d/override.conf':
      ensure  => present,
      notify  => [
        Service['rsyslog'],
        Class['puppet_infrastructure::systemd_daemon_reload'], # This should be removed for Puppet >= 6.1
      ],
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      source  => 'puppet:///modules/puppet_infrastructure/elk/rsyslog.service-override',
      require => File['/etc/systemd/system/rsyslog.service.d'],
    }

  }

}
