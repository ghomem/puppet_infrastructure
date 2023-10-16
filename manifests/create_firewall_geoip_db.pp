### Purpose ########
# This class generates a csv with a list of
# IP ranges per country from official sources

### WARNING ###
# This class is only suposed to be included in the puppet master 
class puppet_infrastructure::create_firewall_geoip_db ( $minute = 0, $hour = 0, $weekday = 0 ){

  $fw_secure_extra_dir = '/etc/puppetlabs/puppet/extra_files/fw_secure_extra'

  $localdir = lookup('filesystem::localdir')
  
  $local_geoip_dir = "${localdir}/geoip"
  $repo_location = "${local_geoip_dir}/ip-countryside"
  $out_csv_location = "${$local_geoip_dir}/GeoIP-legacy.csv"
  $ip_db_location = "${$local_geoip_dir}/ip-countryside/ip2country.db"
  
  package { 'g++':
    ensure => present,
  }
  
  file { $fw_secure_extra_dir:
    ensure => directory,
  }
    
  file {"${local_geoip_dir}/generate_csv.py":
    ensure  => present,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => template('puppet_infrastructure/fw_secure_extra/generate_csv.py.erb')
  }
  
  file {"${local_geoip_dir}/run_db_procedure.sh":
    ensure  => present,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => template('puppet_infrastructure/fw_secure_extra/run_db_procedure.sh.erb')
  }
  
  vcsrepo { $repo_location:
    ensure   => latest,
    provider => git,
    source   => 'https://github.com/Markus-Go/ip-countryside.git',
    revision => 'master',
  }
  
  cron { 'Generate GeoIP database':
    command => "${$local_geoip_dir}/run_db_procedure.sh",
    user    => 'root',
    weekday => $weekday,
    hour    => $hour,
    minute  => $minute,
    require => [ File["${local_geoip_dir}/run_db_procedure.sh", "${local_geoip_dir}/generate_csv.py"], Vcsrepo[$repo_location] ],
  }

}
