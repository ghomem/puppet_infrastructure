node 'puppet' {

  include puppet_infrastructure::node_base
  include puppet_infrastructure::puppet_reports_cleanup
  include puppet_infrastructure::hashman_base
  include puppet_infrastructure::mcollective_master

  # uncomment only after SSL cert and key are deployed
  #include puppet_infrastructure::hashman_web

  # uncoment only when credentials are set on common.yaml
  # email sending via external relay
  # include puppet_infrastructure::postfix_smtp_node

  # puppet specific firewall rules
  firewall { '200 accept puppet':      proto  => 'tcp', dport  => 8140,  action => 'accept', }
  firewall { '201 accept mcollective': proto  => 'tcp', dport  => 61614, action => 'accept', }
  firewall { '300 hashman HTTPS     ': proto  => 'tcp', dport  => 443,   action => 'accept', }
  firewall { '301 hashman HTTP redir': proto  => 'tcp', dport  => 80,    action => 'accept', }

  # make sure the class is present at nodes/passwd/generic.pp even if empty
  include passwd_common

  # ensure our hiera sensitive files are not world-readable
  File {'/etc/puppetlabs/code/environments/production/data/common.yaml':
    ensure => present,
    owner  => 'puppet',
    group  => 'puppet',
    mode   => 'u=rw,g=r,o=',
  }

}
