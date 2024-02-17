### Purpose ########
# This class configures an mcollective node service, which receives commands from the mcollective master
class puppet_infrastructure::mcollective_node {

  $libdir    = lookup(mcollective_node::mcolibdir)
  $mcomaster = lookup(mcollective_node::mcomaster)
  $mcoport   = lookup(mcollective_node::mcoport)
  $mcouser   = lookup(mcollective_node::mcouser)
  $mcopass   = lookup(mcollective_node::mcopass)

  # Ensure the entire directory path exists
  file { '/opt/puppetlabs/mcollective':
    ensure => directory,
  }

  file { '/opt/puppetlabs/mcollective/plugins':
    ensure => directory,
  }

  # create directories and push files
  file { [ $libdir , "${libdir}/agent/" , "${libdir}/agent/shell", "${libdir}/application","${libdir}/application/shell"]: ensure => directory }
  -> file { "${libdir}/agent/shell.ddl": source => 'puppet:///modules/puppet_infrastructure/mcollective/agent/shell.ddl', }
  -> file { "${libdir}/agent/shell.rb": source => 'puppet:///modules/puppet_infrastructure/mcollective/agent/shell.rb', }
  -> file { "${libdir}/agent/shell/job.rb": source => 'puppet:///modules/puppet_infrastructure/mcollective/agent/shell/job.rb', }
  -> file { "${libdir}/application/shell.rb": source => 'puppet:///modules/puppet_infrastructure/mcollective/application/shell.rb', }
  -> file { "${libdir}/application/shell/prefix_stream_buf.rb": source => 'puppet:///modules/puppet_infrastructure/mcollective/application/shell.rb', }
  -> file { "${libdir}/application/shell/watcher.rb": source => 'puppet:///modules/puppet_infrastructure/mcollective/application/shell/watcher.rb', }
  -> file { '/etc/puppetlabs/mcollective/server.cfg':
    owner   => 'root',
    mode    => '0600',
    notify  => Service['mcollective'],
    content => template('puppet_infrastructure/mcollective/mcollective_server.cfg.erb'),
  }

  service { 'mcollective':
    ensure   => running,
    enable   => true,
    provider => 'systemd',
  }

}
