### Purpose ########
# This class provides a base firewall configuration that DROPs INPUT and FORWARD
# allowing OUTPUT and specific INPUTs for SSH and ICMP along with SSH brute force mitigation

### Dependencies ###
#  modules: puppetlabs-firewall
class puppet_infrastructure::firewall_secure ( 
  $acl                           = [],
  $ssh_port                      = 22,
  Boolean $strict                = false,
  Boolean $strict_purge          = true, 
  Array[String] $ignore_patterns = [], 
){
  Firewall {
    require => undef,
  }

  $localdir = lookup('filesystem::localdir')

  # Script that clears all firewall rules to be used only in exceptional cases (see issue 119)
  file { "${localdir}/bin/iptables-flush.sh":
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    source  => 'puppet:///modules/puppet_infrastructure/iptables/iptables-flush.sh',
    require => File[ "${localdir}/bin" ],
  }

  # white list of hosts that can login (strict mode) or bypass protections (default mode)
  # puppet will abort if the whitelist is not present
  $whitelist = lookup('firewall::whitelist')

  # join the existing white list with the specific node acl
  $mylist = unique ( flatten( [ $whitelist, $acl ] ) )

  # Purge all firewall rules not managed by puppet, unless strict_purge is false
  resources { 'firewall': purge => $strict_purge }

  # Policies and purges, with a patternized exception
  if ( ! $strict_purge and ! $ignore_patterns.empty )
  {
    $regex_ignore_patterns = $ignore_patterns.map | $pattern | { "[^\"]*(?i:${pattern})[^\"]*" }

    firewallchain { 'FORWARD:filter:IPv4': ensure => present, purge => true, policy => drop, ignore => $regex_ignore_patterns }
    firewallchain { 'INPUT:filter:IPv4':   ensure => present, purge => true, policy => drop, ignore => $regex_ignore_patterns }
  }
  else
  {
    firewallchain { 'FORWARD:filter:IPv4': ensure => present, purge => true, policy => drop }
    firewallchain { 'INPUT:filter:IPv4':   ensure => present, purge => true, policy => drop }
  }


  # Default firewall rules
  firewall { '000 accept all icmp':
    proto  => 'icmp',
    action => 'accept',
  }
  -> firewall { '001 accept all to lo interface':
    proto   => 'all',
    iniface => 'lo',
    action  => 'accept',
  }
  -> firewall { '002 reject local traffic not on loopback interface':
    iniface     => '! lo',
    proto       => 'all',
    destination => '127.0.0.1/8',
    action      => 'reject',
  }
  -> firewall { '003 accept related established rules':
    proto  => 'all',
    state  => ['RELATED', 'ESTABLISHED'],
    action => 'accept',
  }

  # paramters for every other host
  $indilim='8'           # limit for individual IP simultaneous connections
  $indilim_minute='15'   # limit individual IP new connections attempts per minute
  $overlim_minute='20'   # overall limit for new connections per minute

  # allow unfiltered access to the list of IPs
  $mylist.each |String $ip| {
    firewall { "100 SSH whitelist ${ip}":  chain => 'INPUT', proto  => 'tcp', dport  => $ssh_port, source => $ip,  action => 'accept', }
  }

  # on strict mode only listed IPs can actually access the system
  if ( $strict == true ) {
    firewallchain { 'LIMIT_OVERALL:filter:IPv4':    ensure  => present }
    -> firewall { '117 SSH DROP':               chain => 'LIMIT_OVERALL', proto => tcp, dport => $ssh_port, action => 'drop' }
  }
  else {
    firewallchain { 'LIMIT_INDIVIDUAL:filter:IPv4': ensure  => present }
    -> firewallchain { 'LIMIT_OVERALL:filter:IPv4':    ensure  => present }
    -> firewall { '110 SSH LIMIT_INDIVIDUAL':   chain => 'INPUT', proto => tcp, dport => $ssh_port, tcp_flags => 'FIN,SYN,RST,ACK SYN', state => 'NEW', jump => 'LIMIT_INDIVIDUAL' }
    -> firewall { '111 SSH ACCEPT ESTABLISHED': chain => 'INPUT', proto => tcp, dport => $ssh_port, state => 'ESTABLISHED', action => 'accept' }
    -> firewall { '112 SSH connlimit':          chain => 'LIMIT_INDIVIDUAL', proto => tcp, dport => $ssh_port, connlimit_above => $indilim, action => 'drop', }
    -> firewall { '113 SSH set recent':         chain => 'LIMIT_INDIVIDUAL', proto => tcp, dport => $ssh_port, recent => 'set' }
    -> firewall { '114 SSH set recent':         chain => 'LIMIT_INDIVIDUAL', proto => tcp, dport => $ssh_port, recent => 'update', rseconds => '60', rhitcount => $indilim_minute, action => 'drop' }
    -> firewall { '115 SSH LIMIT_INDIVIDUAL':   chain => 'LIMIT_INDIVIDUAL', proto => tcp, dport => $ssh_port, jump => 'LIMIT_OVERALL' }
    -> firewall { '116 SSH LIMIT_OVERALL':      chain => 'LIMIT_OVERALL', proto => tcp, dport => $ssh_port, limit => "${overlim_minute}/min", action => 'accept' }
    -> firewall { '117 SSH DROP':               chain => 'LIMIT_OVERALL', proto => tcp, dport => $ssh_port, action => 'drop' }
  }

}
