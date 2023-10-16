### Purpose ########
# This class sets up a ELK (elasticsearch + logstash + kibana) server

## For documentation please refer to:
# https://bitbucket.org/asolidodev/puppet_infrastructure/wiki/Class%20ELK%20(Server%20and%20client)

class puppet_infrastructure::elk_server (

    Integer $kibana_request_timeout = 30000, # this is in miliseconds

){

  if ( $::osfamily == 'RedHat' ) {

    group { 'syslog': ensure => 'present', gid => 0, allowdupe => true }
    user  { 'syslog': ensure => 'present', uid => 0, allowdupe => true }

  }

  $use_rsyslog_failover   = lookup({ name => 'elk::server::cluster', default_value => false })
  $use_logstash_failover  = lookup({ name => 'elk::server::cluster', default_value => false })

  if ( $use_rsyslog_failover ) {
    $elk_server_failover    = lookup({ name => [ "${server_node}::elk::server::elk_server_failover", 'elk::server::elk_server_failover' ] })
    $elk_server_failover_ip = lookup({ name => [ "${server_node}::elk::server::elk_server_failover_ip", 'elk::server::elk_server_failover_ip' ] })
  }

  $is_server_staging               = lookup({ name => "${clientcert}::elk::server::is_server_staging", default_value => false })
  $instance_id                     = lookup({ name => [ "${clientcert}::elk::server::instance_id", 'elk::server::instance_id' ] , default_value => 'es01' })
  $logstash_ssl_verify             = lookup({ name => [ "${clientcert}::elk::server::logstash_ssl_verify", 'elk::server::logstash_ssl_verify' ] , default_value => true })
  $retention_period                = lookup({ name => [ "${clientcert}::elk::server::retention_period", 'elk::server::retention_period' ] , default_value => '30' })
  $elasticsearch_logfile_retention = lookup({ name => [ "${clientcert}::elk::server::elasticsearch_logfile_retention", 'elk::server::elasticsearch_logfile_retention' ] , default_value => '15' })
  $elasticsearch_gc_files          = lookup({ name => [ "${clientcert}::elk::server::elasticsearch_gc_files", 'elk::server::elasticsearch_gc_files' ] , default_value => '2' })
  $kibana_host                     = lookup({ name => [ "${clientcert}::elk::server::kibana_host", 'elk::server::kibana_host' ] , default_value => '127.0.0.1' })
  $data_dir                        = lookup({ name => [ "${clientcert}::elk::server::data_dir", 'elk::server::data_dir' ] , default_value => '/var/lib/elasticsearch' })
  $log_dir                         = lookup({ name => [ "${clientcert}::elk::server::log_dir", 'elk::server::log_dir' ] , default_value => '/var/log/elasticsearch' })
  $repo_dirs                       = lookup({ name => [ "${clientcert}::elk::server::repo_dirs", 'elk::server::repo_dirs' ] , default_value => '' })
  $pkgsdir                         = lookup('filesystem::pkgsdir')

  # components instalation/activation
  $elk_server_log_itself = lookup({ name => "${clientcert}::elk::server::elk_server_log_itself", default_value => true })
  $install_kibana        = lookup({ name => "${clientcert}::elk::server::install_kibana", default_value => true })
  $install_logstash      = lookup({ name => "${clientcert}::elk::server::install_logstash", default_value => true })

  # Elasticsearch disk managment
  $elasticsearch_disk_threshold_enabled     = lookup({ name => [ "${clientcert}::elk::server::elasticsearch_disk_threshold_enabled",     'elk::server::elasticsearch_disk_threshold_enabled' ] ,     default_value => true })
  $elasticsearch_disk_watermark_low         = lookup({ name => [ "${clientcert}::elk::server::elasticsearch_disk_watermark_low",         'elk::server::elasticsearch_disk_watermark_low' ] ,         default_value => '50gb' })
  $elasticsearch_disk_watermark_high        = lookup({ name => [ "${clientcert}::elk::server::elasticsearch_disk_watermark_high",        'elk::server::elasticsearch_disk_watermark_high' ] ,        default_value => '10gb' })
  $elasticsearch_disk_watermark_flood_stage = lookup({ name => [ "${clientcert}::elk::server::elasticsearch_disk_watermark_flood_stage", 'elk::server::elasticsearch_disk_watermark_flood_stage' ] , default_value => '5gb' })

  if ( $is_server_staging ) {

    $ca_path          = 'puppet_infrastructure/elk/ca-staging.pem'
    $cert_server_path = 'puppet_infrastructure/elk/server-cert-staging.pem'
    $key_server_path  = 'puppet_infrastructure/elk/server-key-staging.pem'
    $cert_client_path = 'puppet_infrastructure/elk/client-cert-staging.pem'
    $key_client_path  = 'puppet_infrastructure/elk/client-key-staging.pem'
    $server_node      = 'elk-staging'
    $elk_server       = 'logs-staging.angulosolido.pt'
    $elk_server_ip    = $ipaddress

  }
  else {

    $ca_path          = lookup( [ "${clientcert}::elk::ca_path", 'elk::ca_path' ] )
    $cert_server_path = lookup( [ "${clientcert}::elk::server::cert_server_path", 'elk::server::cert_server_path' ] )
    $key_server_path  = lookup( [ "${clientcert}::elk::server::key_server_path", 'elk::server::key_server_path' ] )
    $cert_client_path = lookup( [ "${clientcert}::elk::client::cert_client_path", 'elk::client::cert_client_path' ] )
    $key_client_path  = lookup( [ "${clientcert}::elk::client::key_client_path", 'elk::client::key_client_path' ] )
    $server_node      = lookup( [ "${clientcert}::elk::client::servernodename", 'elk::client::servernodename' ] )
    $elk_server       = lookup( [ "${server_node}::elk::server::elk_server", 'elk::server::elk_server' ] )
    $elk_server_ip    = lookup( [ "${server_node}::elk::server::elk_server_ip", 'elk::server::elk_server_ip' ] )

  }

  include ::java

  class { 'elastic_stack::repo':
      version => 6,
    }

# elasticsearch part
   
  $elastic_default_config = {
      'cluster.routing.allocation.disk.threshold_enabled'     => $elasticsearch_disk_threshold_enabled,
      'cluster.routing.allocation.disk.watermark.low'         => $elasticsearch_disk_watermark_low,
      'cluster.routing.allocation.disk.watermark.high'        => $elasticsearch_disk_watermark_high,
      'cluster.routing.allocation.disk.watermark.flood_stage' => $elasticsearch_disk_watermark_flood_stage,
    }

  # In case elk::server::repo_dirs (path.repo) is not defined on node, do not add it to ES instance config.
  $elastic_config = $repo_dirs ? {
    ''      => $elastic_default_config,
    default => merge($elastic_default_config, {'path.repo' => $repo_dirs})
  }

  class { 'elasticsearch':
    restart_on_change => true,
    version           => '6.2.4',
    instances         => {
      $instance_id => {
        'config' => $elastic_config
      }
    },
    jvm_options       => [
    "-XX:NumberOfGCLogFiles=${elasticsearch_gc_files}"
    ],
    datadir           => $data_dir,
    logdir            => $log_dir,
  }

  # cron job for logfiles cleanup
  cron { 'cron_elasticsearch_logfile_cleanup':
  command  => "find /var/log/elasticsearch/${$instance_id}/ -type f -mtime +${elasticsearch_logfile_retention} | xargs rm",
  user     => 'elasticsearch',
  monthday => '*',
  hour     => '0',
  minute   => '27',
  require  => [
    Class['elasticsearch'],
    ],
  }

# elasticsearch curator part

  case $facts['os']['distro']['codename'] {
    'trusty', 'xenial': { $curator_url = 'https://packages.elastic.co/curator/5/debian/pool/main/e/elasticsearch-curator/elasticsearch-curator_5.6.0_amd64.deb' }
    default: { $curator_url = 'https://packages.elastic.co/curator/5/debian9/pool/main/e/elasticsearch-curator/elasticsearch-curator_5.6.0_amd64.deb' }
  }

  file { "${pkgsdir}/elasticsearch-curator_amd64.deb":
    ensure => 'present',
    source => $curator_url,
  }

  package { 'elasticsearch-curator':
    ensure   => 'installed',
    source   => "${pkgsdir}/elasticsearch-curator_amd64.deb",
    provider => dpkg,
    require  => [
      Class['elasticsearch'],
      File["${pkgsdir}/elasticsearch-curator_amd64.deb"],
    ],
  }

  file { '/etc/curator':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
  }

  file { '/etc/curator/curator.yml':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => file('puppet_infrastructure/elk/curator.yml'),
    require => [
      File['/etc/curator'],
      ],    }

  file { '/etc/curator/action.yml':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => template('puppet_infrastructure/elk/action.yml.erb'),
    require => [
      File['/etc/curator'],
      ],    }

  cron { 'curator':
    command => '/usr/bin/curator /etc/curator/action.yml --config /etc/curator/curator.yml',
    user    => 'root',
    minute  => '27',
    hour    => '3',
    require => [
      File['/etc/curator/action.yml'],
      ],    }

# kibana part
if ( $install_kibana ) {
    class { 'kibana' :
      ensure => '6.2.4',
      config => {
        'server.port'                  => '5601',
        'server.host'                  => $kibana_host,
        'elasticsearch.requestTimeout' => $kibana_request_timeout,
      }
    }
  }
  else {
    package { 'kibana': ensure => 'purged', }
  }

# logstash part
if ( $install_logstash ) {
    class { 'logstash':
      version => '1:6.2.4-1',
    }

    logstash::configfile { 'logstash.conf':
      content => template('puppet_infrastructure/elk/logstash.conf.erb'),
    }

    file { '/etc/ssl/logstash-server-cert.pem':
      notify  => Service['logstash'],
      mode    => '0600',
      owner   => 'logstash',
      group   => 'logstash',
      replace => 'yes',
      content => file($cert_server_path),
      require => [
        Class['logstash::package'],
        ],
    }

    file { '/etc/ssl/logstash-server-key.pem':
      notify  => Service['logstash'],
      mode    => '0600',
      owner   => 'logstash',
      group   => 'logstash',
      replace => 'yes',
      content => file($key_server_path),
      require => [
        Class['logstash::package'],
        ],
    }
  }
  else {
    package { 'logstash': ensure => 'purged', }

    file { '/etc/ssl/logstash-server-cert.pem':
      ensure => 'absent'
    }

    file { '/etc/ssl/logstash-server-key.pem':
      ensure => 'absent'
    }
  }

# hold ELK packages

  apt::pin { 'elastic':
    ensure      => present,
    explanation => 'Elastic needs this versions',
    priority    => 1001,
    packages    => 'elasticsearch',
    version     => '6.2.4',
  }

  if ( $install_kibana ) {
    apt::pin { 'kibana':
      ensure      => present,
      explanation => 'Elastic needs this versions',
      priority    => 1001,
      packages    => 'kibana',
      version     => '6.2.4',
    }
  }

  if ( $install_logstash ) {
    apt::pin { 'logstash':
      ensure      => present,
      explanation => 'Elastic needs this versions',
      priority    => 1001,
      packages    => 'logstash',
      version     => '1:6.2.4-1',
    }
  }

# rsyslog part
  if ( $elk_server_log_itself ) {

    package { 'rsyslog-gnutls': ensure => 'installed', }

    host { $elk_server:
      ip     => $elk_server_ip,
      notify => Service['rsyslog'],
    }
    if ( $use_rsyslog_failover ) {
      host { $elk_server_failover:
        ip     => $elk_server_failover_ip,
        notify => Service['rsyslog'],
      }
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
  }

# both logstash and rsyslog need this CA
  if ( $install_logstash ) or ( $elk_server_log_itself ) {

    file { '/etc/ssl/logstash-ca.pem':
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      replace => 'yes',
      content => file($ca_path),
    }

  }

}
