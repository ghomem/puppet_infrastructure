### Purpose ########
# This class provides an extension of firewall secure with some extra features
# like ddos mitigation and geographical IP filtering

# This class also offers anti ddos protection and the abillity to use a side chain
# to whitelist IPs with rate limiting

### Dependencies ###
#  modules: puppetlabs-firewall

### WARNING ###
# this class provides a whitelist with a firewall sidechain based on country
# When performing changes to the input variables of this class, running /usr/local/AS/bin/iptables-flush.sh IS REQUIRED
class puppet_infrastructure::firewall_secure_extra ( $strict = false,
                                        $acl = [],
                                        $anti_ddos = false, # if this is true all the variables bellow will be used
                                        # WARNING Changes to this variable may require manual iptables flush
                                        $service_list = [], # this var should be a list of lists: [['service_port', 'service_protocol'],['service_port', 'service_protocol'],['service_port', 'service_protocol']]
                                        String $ddos_limit = '100' ,
                                        String $ddos_limit_per_time_unit = '60',
                                        String $ddos_limit_time_unit = 'sec', # to avoid long outputs from puppet runs, the units should be sec | min and not s | m
                                        Boolean $ip_filter = false, # when true restricts access (with rate limiting) to $service_list from $country_whitelist + $ip_whitelist
                                        String $country_whitelist = '', # Country alpha-2 codes seperated by commas. Ex: 'PT,ES,GB'
                                        Array $ip_whitelist = [], # list of strings containing source IPs to be accepted by ip_filter rules
                                        Array $ip_blacklist = [], # list of strings containing source IPs to be dropped unconditionally
                                        Boolean $internal_forward = false, # forward world to a default landing page
                                        
                                        # this var should be a list of lists: [['internal_ipaddr', 'internal_http_port'], ['internal_ipaddr', 'internal_https_port']]
                                        # these services are the port forwards for the ones at $service_list
                                        # so the var needs to have the same length and same relation order
                                        $internal_forward_list = [],
                                        
                                        String $forward_iniface = '', # public interface name from where the packets will be port forwarded
                                        String $good_mark = '0x413',
                                        String $bad_mark = '0x406',
                                        $ssh_port = 22,
) {
  
  if( $ip_filter and !$anti_ddos ) {
    fail('IP filtering only works together with anti ddos measures.')
  }
  elsif ( $ip_filter and (length($country_whitelist) == 0) and (length($ip_whitelist) == 0)){
    fail('IP filtering needs at least one of these variables set: $country_whitelist | $ip_whitelist')
  }
  
  if ( $internal_forward and ! (length($internal_forward_list) == length($service_list))){
    fail ('$internal_forward_list and $service_list need to have the same amount of elements')
  }
  
  if ( $internal_forward and $forward_iniface == ''){
    fail ('If internal services are provided, $forward_iniface should also be provided')
  }
  
  
  Firewall {
    require => undef,
  }

  $localdir = lookup('filesystem::localdir')
  
  $last_array_service = $service_list[-1]

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

  # Purge all firewall rules not managed by puppet
  resources { 'firewall': purge => true, }

  # Policies
  firewallchain { 'FORWARD:filter:IPv4': ensure => present, purge => true, policy => drop   }
  firewallchain { 'INPUT:filter:IPv4':   ensure => present, purge => true, policy => drop   }

  # Default firewall rules
  if ( $anti_ddos ){
    firewall { '000 ICMP limit':
      chain  => 'INPUT',
      proto  => 'icmp',
      icmp   => 'echo-request',
      limit  => '2/sec',
      action => 'accept'
    }
    -> firewall { '000 icmp drop':
      chain  => 'INPUT',
      proto  => 'icmp',
      action => 'drop',
    }
  } else {
    
    firewall { '000 accept all icmp':
      proto  => 'icmp',
      action => 'accept',
    }
    
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
  
  $ip_blacklist.each |$bad_ip|{
    firewall { "666 grounding naughty boys: ${bad_ip}":  chain => 'INPUT', source => $bad_ip,  action => 'drop', }
  }

  # paramters for every other host
  $indilim='8'           # limit for individual IP simultaneous connections
  $indilim_minute='15'   # limit individual IP new connections attempts per minute
  $overlim_minute='20'   # overall limit for new connections per minute

  # allow unfiltered access to the list of IPs
  $mylist.each |String $ip| {
    firewall { "100 SSH whitelist ${ip}": chain => 'INPUT', proto  => 'tcp', dport  => $ssh_port, source => $ip,  action => 'accept', }
  }

  # on strict mode only listed IPs can actually access the system
  if ( $strict == true ) {
    firewallchain { 'LIMIT_OVERALL:filter:IPv4': ensure  => present }
    firewall { '117 SSH DROP': chain => 'LIMIT_OVERALL', proto => tcp, dport => $ssh_port, action => 'drop' }
  }
  else {
    firewallchain { 'LIMIT_INDIVIDUAL:filter:IPv4': ensure  => present }
    -> firewallchain { 'LIMIT_OVERALL:filter:IPv4':    ensure  => present }
    -> firewall { '110 SSH LIMIT_INDIVIDUAL':   chain => 'INPUT',            proto => tcp, dport => $ssh_port, tcp_flags       => 'FIN,SYN,RST,ACK SYN', state => 'NEW', jump => 'LIMIT_INDIVIDUAL' }
    -> firewall { '111 SSH ACCEPT ESTABLISHED': chain => 'INPUT',            proto => tcp, dport => $ssh_port, state           => 'ESTABLISHED', action => 'accept' }
    -> firewall { '112 SSH connlimit':          chain => 'LIMIT_INDIVIDUAL', proto => tcp, dport => $ssh_port, connlimit_above => $indilim, action => 'drop', }
    -> firewall { '113 SSH set recent':         chain => 'LIMIT_INDIVIDUAL', proto => tcp, dport => $ssh_port, recent          => 'set' }
    -> firewall { '114 SSH set recent':         chain => 'LIMIT_INDIVIDUAL', proto => tcp, dport => $ssh_port, recent          => 'update', rseconds => '60', rhitcount => $indilim_minute, action => 'drop' }
    -> firewall { '115 SSH LIMIT_INDIVIDUAL':   chain => 'LIMIT_INDIVIDUAL', proto => tcp, dport => $ssh_port, jump            => 'LIMIT_OVERALL' }
    -> firewall { '116 SSH LIMIT_OVERALL':      chain => 'LIMIT_OVERALL',    proto => tcp, dport => $ssh_port, limit           => "${overlim_minute}/min", action => 'accept' }
    -> firewall { '117 SSH DROP':               chain => 'LIMIT_OVERALL',    proto => tcp, dport => $ssh_port, action          => 'drop' }
  }
  
  if ( $anti_ddos ) {
    
    ### 1: Drop invalid packets ### 
    firewall { '501 drop invalid packets': chain => 'PREROUTING', table => 'mangle', ctstate => 'INVALID', action => 'drop', }

    ### 2: Drop TCP packets that are new and are not SYN ###
    -> firewall { '502 drop new packets not syn': chain => 'PREROUTING', table => 'mangle', proto => 'tcp', tcp_flags => '! FIN,SYN,RST,ACK SYN', ctstate => 'NEW', action => 'drop', }
    
    ### 3: Drop SYN packets with suspicious MSS value ### 
    -> firewall { '503 drop syn packets with suspicious mss': chain => 'PREROUTING', table => 'mangle', proto => 'tcp', ctstate => 'NEW', mss => '! 536:65535', action  => 'drop', }

    ### 4: Block packets with bogus TCP flags ###
    -> firewall { '504 drop packets bogus tcp flags': chain => 'PREROUTING', table => 'mangle', proto => 'tcp', tcp_flags => 'FIN,SYN,RST,PSH,ACK,URG NONE',                    action => 'drop', }
    -> firewall { '505 drop packets bogus tcp flags': chain => 'PREROUTING', table => 'mangle', proto => 'tcp', tcp_flags => 'FIN,SYN FIN,SYN',                                 action => 'drop', }
    -> firewall { '506 drop packets bogus tcp flags': chain => 'PREROUTING', table => 'mangle', proto => 'tcp', tcp_flags => 'SYN,RST SYN,RST',                                 action => 'drop', }
    -> firewall { '507 drop packets bogus tcp flags': chain => 'PREROUTING', table => 'mangle', proto => 'tcp', tcp_flags => 'FIN,SYN FIN,SYN',                                 action => 'drop', }
    -> firewall { '508 drop packets bogus tcp flags': chain => 'PREROUTING', table => 'mangle', proto => 'tcp', tcp_flags => 'FIN,RST FIN,RST',                                 action => 'drop', }
    -> firewall { '509 drop packets bogus tcp flags': chain => 'PREROUTING', table => 'mangle', proto => 'tcp', tcp_flags => 'FIN,ACK FIN',                                     action => 'drop', }
    -> firewall { '510 drop packets bogus tcp flags': chain => 'PREROUTING', table => 'mangle', proto => 'tcp', tcp_flags => 'ACK,URG URG',                                     action => 'drop', }
    -> firewall { '511 drop packets bogus tcp flags': chain => 'PREROUTING', table => 'mangle', proto => 'tcp', tcp_flags => 'FIN,ACK FIN',                                     action => 'drop', }
    -> firewall { '512 drop packets bogus tcp flags': chain => 'PREROUTING', table => 'mangle', proto => 'tcp', tcp_flags => 'PSH,ACK PSH',                                     action => 'drop', }
    -> firewall { '513 drop packets bogus tcp flags': chain => 'PREROUTING', table => 'mangle', proto => 'tcp', tcp_flags => 'FIN,SYN,RST,PSH,ACK,URG FIN,SYN,RST,PSH,ACK,URG', action => 'drop', }
    -> firewall { '514 drop packets bogus tcp flags': chain => 'PREROUTING', table => 'mangle', proto => 'tcp', tcp_flags => 'FIN,SYN,RST,PSH,ACK,URG NONE',                    action => 'drop', }
    -> firewall { '515 drop packets bogus tcp flags': chain => 'PREROUTING', table => 'mangle', proto => 'tcp', tcp_flags => 'FIN,SYN,RST,PSH,ACK,URG FIN,PSH,URG',             action => 'drop', }
    -> firewall { '516 drop packets bogus tcp flags': chain => 'PREROUTING', table => 'mangle', proto => 'tcp', tcp_flags => 'FIN,SYN,RST,PSH,ACK,URG FIN,SYN,PSH,URG',         action => 'drop', }
    -> firewall { '517 drop packets bogus tcp flags': chain => 'PREROUTING', table => 'mangle', proto => 'tcp', tcp_flags => 'FIN,SYN,RST,PSH,ACK,URG FIN,SYN,RST,ACK,URG',     action => 'drop', }

    ### 7: Drop fragments in all chains ###
    -> firewall { '518 drop fragmented packages': chain => 'PREROUTING', table => 'mangle', isfragment => true, action => 'drop', }
    
    ### 8: Limit RST packets ###
    firewall { '519 limit RST tcp packets': chain => 'INPUT', proto => 'tcp', limit => '2/sec', burst => '2', tcp_flags => 'RST RST', action => 'accept', }
    
    -> firewall { '520 limit RST tcp packets (default behavior)': chain => 'INPUT', proto => 'tcp', tcp_flags => 'RST RST', action => 'drop', }
    
    if ($ip_filter){
      ### Here we whitelist the ip networks per name or country
        
      # first create the side chain
      firewallchain { 'WHITELIST_SIDE_CHAIN:filter:IPv4': ensure  => present }
      
      # first we mark all traffic in order to avoid sending good people to the wrong webserver
      firewall { '131313 marking all traffic at entry': chain => 'PREROUTING', table => 'mangle', proto => 'tcp', set_mark => $bad_mark, jump => 'MARK', }
      
      # then add the whitelist rules to redirect
      # the packets to the sidechain
      if(length($country_whitelist) > 0) {
        ### here we are marking packets that are from allowed countries to jump to sidechain later
        firewall { '131313 marking country WHITELIST': chain => 'PREROUTING', table => 'mangle', proto => 'tcp', src_cc => $country_whitelist, set_mark => $good_mark, jump => 'MARK', }
      }
      
      # marking the whitelisted IPs to jump to sidechain later
      $ip_whitelist.each |$good_ip|{
        firewall { "131313 marking the good boys: ${good_ip}": chain => 'PREROUTING', table => 'mangle', proto => 'all', source => $good_ip, set_mark => $good_mark, jump => 'MARK', }
      }
      
      # rules that port forward marked packets to corresponding
      # IPs and ports that have services on the internal interface
      if ($internal_forward) {
        $service_list.each |Integer $index, Array $value|{
          $my_dest = $internal_forward_list[$index][0]
          $my_dest_port = $internal_forward_list[$index][1]
          firewall { "131313 port forwarding: ${my_dest}:${my_dest_port}": chain => 'PREROUTING', table => 'nat', proto => $service_list[$index][1], dport => $service_list[$index][0], match_mark => $bad_mark, todest => "${my_dest}:${my_dest_port}", jump => 'DNAT', }
        }
      }
      
      firewall { '521 sidechain redirecting by mark': chain => 'INPUT', proto => 'all', match_mark => $good_mark, jump => 'WHITELIST_SIDE_CHAIN', }
        
      ### 9: Limit connections per source IP ###
      $service_list.each |$service| {
        firewall { "521 limit connections per source IP ${service}": chain => 'WHITELIST_SIDE_CHAIN', proto => $service[1], dport => $service[0], connlimit_above => $ddos_limit, action => 'drop', require => Firewall['518 drop fragmented packages'] }
      }
        
      ### 10: Limit new connections per second per source IP ###
      $service_list.each |$service| {
        firewall { "522 limit mew connections per source IP and time unit ${service}":
          chain   => 'WHITELIST_SIDE_CHAIN',
          ctstate => 'NEW',
          proto   => $service[1],
          limit   => "${ddos_limit_per_time_unit}/${ddos_limit_time_unit}",
          dport   => $service[0],
          action  => 'accept',
          require => Firewall['520 limit RST tcp packets (default behavior)']
        }
        
        -> firewall { "523 limit mew connections per source IP and time unit (default behavior): ${service}":
          chain   => 'WHITELIST_SIDE_CHAIN',
          ctstate => 'NEW',
          proto   => $service[1],
          dport   => $service[0],
          action  => 'drop',
          require => Firewall["522 limit mew connections per source IP and time unit ${service}"]
        }
      }
      
      firewall { '524 drop all traffic in the side chain': chain => 'WHITELIST_SIDE_CHAIN', action => 'drop', }
      
      if ($internal_forward) {
        $internal_forward_list.each |$internal_service| {
          # rules to allow the forwarding of packets to the internal IP:PORT that hosts the service
          firewall { "123123123 allow forward ${internal_service}": chain => 'FORWARD', table => 'filter', iniface => $forward_iniface, dport => $internal_service[1], destination => $internal_service[0], action => 'accept', }


          # in the rules bellow we do not consider protocol because the only traffic
          # arriving to this interface is either trusted or purposelly forward into here
          # rules to allow http and https on the internal IP:PORT that runs the server
          firewall { "123123123 internal limit per source IP ${internal_service}": chain => 'INPUT', destination => $internal_service[0], dport => $internal_service[1], connlimit_above => $ddos_limit, action => 'drop', }

          firewall { "123123123 limit mew connections per source IP and time unit ${internal_service}": chain => 'INPUT', destination => $internal_service[0], ctstate => 'NEW', limit => "${ddos_limit_per_time_unit}/${ddos_limit_time_unit}", dport => $internal_service[1], action => 'accept',}
        }
      }
    }
    else {
      ### 9: Limit connections per source IP ###
      $service_list.each |$service| {
        firewall { "521 limit connections per source IP ${service}":
          chain           => 'INPUT',
          proto           => $service[1],
          dport           => $service[0],
          connlimit_above => $ddos_limit,
          action          => 'drop',
          require         => Firewall['518 drop fragmented packages']
        }
      }
      
      ### 10: Limit new connections per second per source IP ###
      $service_list.each |$service| {
        firewall { "522 limit mew connections per source IP and time unit ${service}":
          chain   => 'INPUT',
          proto   => $service[1],
          ctstate => 'NEW',
          limit   => "${ddos_limit_per_time_unit}/${ddos_limit_time_unit}",
          dport   => $service[0],
          action  => 'accept',
          require => Firewall['520 limit RST tcp packets (default behavior)']
        }
        
        -> firewall { "523 limit mew connections per source IP and time unit (default behavior): ${service}":
          chain   => 'INPUT',
          ctstate => 'NEW',
          proto   => $service[1],
          dport   => $service[0],
          action  => 'drop',
          require => Firewall["522 limit mew connections per source IP and time unit ${service}"]
        }
      }
    }
  }
  
  # the code bellow opens ports to services when we dont
  # want to apply ddos protection, thus just opening the ports
  else {
    $service_list.each |$service| {
      firewall { "555 open service ports: ${service}": chain => 'INPUT', proto => $service[1], dport => $service[0], action => 'accept', }
    }
  }

}
