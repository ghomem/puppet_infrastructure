### Purpose ########
# This class configures the mcollective master
class puppet_infrastructure::mcollective_master {

  $mcomaster = lookup('mcollective_node::mcomaster')
  $mcoport   = lookup('mcollective_node::mcoport')
  $mcouser   = lookup('mcollective_node::mcouser')
  $mcopass   = lookup('mcollective_node::mcopass')

  # rabbitmq configuration
  class { 'rabbitmq':
    port                        => 5672,
    delete_guest_user           => true,
    python_package              => 'python3',
    config_variables            => {
      'ssl_options' =>
        "[
          {cacertfile,\"/etc/puppetlabs/puppet/ssl/certs/ca.pem\"},
          {certfile,\"/etc/puppetlabs/puppet/ssl/certs/${clientcert}.pem\"},
          {keyfile,\"/etc/puppetlabs/puppet/ssl/private_keys/${clientcert}.pem\"},
          {verify,verify_none},
          {fail_if_no_peer_cert,false}
         ]"
    },
    config_additional_variables => {
      'rabbitmq_stomp' => "[ {ssl_listeners, [{\"0.0.0.0\", ${mcoport}}]} ]",
    }
  }

  rabbitmq_plugin {'rabbitmq_stomp':
    ensure => present,
  }

  rabbitmq_user { $mcouser:
    admin    => true,
    password => $mcopass,
    tags     => ['mco'],
  }

  rabbitmq_user_permissions { "${mcouser}@/":
    configure_permission => '.*',
    read_permission      => '.*',
    write_permission     => '.*',
  }

  rabbitmq_exchange { 'mcollective_broadcast@/':
    ensure   => present,
    user     => $mcouser,
    password => $mcopass,
    type     => 'topic',
    # Issue #182 We need to set this to true, because the default is false:
    # https://github.com/voxpupuli/puppet-rabbitmq/blob/master/lib/puppet/type/rabbitmq_exchange.rb#L43
    # Exchanges can be durable or transient. If transient, they are are deleted
    # on a restart of rabbitmq-server.
    # https://www.rabbitmq.com/tutorials/amqp-concepts.html#exchanges
    durable  => true,
  }

  rabbitmq_exchange { 'mcollective_directed@/':
    ensure   => present,
    user     => $mcouser,
    password => $mcopass,
    type     => 'direct',
    # Issue #182 See the comment in the resource above
    durable  => true,
  }

  user { 'rabbitmq':
    groups  => 'puppet',
  }

  # we use the same template for client that we used for server in
  # mcollective_node
  file { '/etc/puppetlabs/mcollective/client.cfg':
    owner   => 'root',
    mode    => '0600',
    notify  => Service['mcollective'],
    content => template('puppet_infrastructure/mcollective/mcollective_server.cfg.erb'),
  }
}
