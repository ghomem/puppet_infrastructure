### Purpose ########
# This class builds a geoip binary database from
# a specifically formated csv file
# that xtables can recognize in order to apply
# geoip iptables rules
class puppet_infrastructure::build_firewall_geoip_db (){
    
    $localdir = lookup('filesystem::localdir')
    $csv_db = "${localdir}/etc/GeoIP-legacy.csv"
    $fw_secure_extra_dir = 'puppet:///extra_files/fw_secure_extra/GeoIP-legacy.csv'
    $geoip_packages = ['xtables-addons-common', 'xtables-addons-dkms', 'libtext-csv-xs-perl']
    
    package { $geoip_packages:
        ensure => present,
    }
    
    exec { 'Build_GeoIP_Database':
      user        => root,
      command     => "${localdir}/bin/load_geoip_db.sh",
      require     => File["${localdir}/bin/load_geoip_db.sh"],
      refreshonly => true,
    }
    
    file { '/usr/share/xt_geoip':
      ensure => directory
    }
    
    file {"${localdir}/bin/load_geoip_db.sh":
      ensure  => present,
      mode    => '0755',
      owner   => 'root',
      group   => 'root',
      content => template('puppet_infrastructure/fw_secure_extra/load_geoip_db.sh.erb')
    }
    
    file {"${localdir}/etc/GeoIP-legacy.csv":
      ensure  => present,
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      source  => ($fw_secure_extra_dir),
      require => File['/usr/share/xt_geoip'],
      notify  => Exec['Build_GeoIP_Database'],
    }
    
}
