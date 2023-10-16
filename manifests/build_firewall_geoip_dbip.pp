### Purpose ########
# This class builds a geoip binary database objects to be used by iptables geoip module
# Please note that if we have this class in an LXD container node declaration,
# we will need to add this line to the LXD server declaration:
# package { 'xtables-addons-dkms': ensure => 'present' }
class puppet_infrastructure::build_firewall_geoip_dbip (
    Integer $dbip_update_monthday,
    Boolean $dbip_full = true,
){
    
    $localdir = lookup('filesystem::localdir')
    $major_release = $facts['os']['release']['major']

    # Set variables related to the dbip file
    if ($dbip_full) {
      # At the moment, we are going to use this -lite filename because it's the only
      # thing that the xt_geoip_build script detects, it has the name harcoded inside
      $dbip_file = '/usr/share/xt_geoip/dbip-country-lite.csv'
      $dbip_key  = lookup('dbip::key')
    } else {
      $dbip_file = '/usr/share/xt_geoip/dbip-country-lite.csv'
    }
   
    # Packages needed to get the geoip module of iptables working (and jq needed for download script)
    $geoip_packages = ['xtables-addons-common', 'xtables-addons-dkms', 'libtext-csv-xs-perl', 'jq']
    package { $geoip_packages:
      ensure  => present,
      require => Exec['apt_update'],
    }

    # Find out xt_geoip_build path depending on ubuntu version
    if ($major_release == '20.04') {
      if ($dbip_full ) {
        # This is a modified version of /usr/lib/xtables-addons/xt_geoip_build,
        # we needed to change one line to make it work with the full dbip database;
        # one difference between the lite version and the full version of the dbip
        # CSV files is the format of the lines:
        # - in the lite vesion the format is:
        #   <ip_range_start>,<ip_range_end>,<country_code>
        #   example:
        #   2.16.65.0,2.16.65.255,EU,PT
        # - in the full vesion the format is:
        #   <ip_range_start>,<ip_range_end>,<REGION_CODE>,<country_code>
        #   example:
        #   2.16.65.0,2.16.65.255,PT
        #
        # The original xt_geoip_build from the ubuntu package works with the lite version
        # format, so we just had to change one line to make it work with the full version
        # format.
        $xt_geoip_build_path = '/usr/lib/xtables-addons/xt_geoip_build_full'
        file {"${xt_geoip_build_path}":
          ensure  => present,
          mode    => '0755',
          owner   => 'root',
          group   => 'root',
          require => Package[$geoip_packages],
          source => ('puppet:///modules/puppet_infrastructure/dbip/xt_geoip_build_full'),
        }
      } else {
        # If we are not using the full dbip file, we can use the xt_geoip_build
        # from the ubuntu package.
        $xt_geoip_build_path = '/usr/lib/xtables-addons/xt_geoip_build'
        # Workaround for xt_geoip_build not being executable in ubuntu 20.04
        file {"${xt_geoip_build_path}":
          ensure  => present,
          mode    => '0755',
          owner   => 'root',
          group   => 'root',
          require => Package[$geoip_packages],
        }
      }
    } else {
      # we expect this path for ubuntu >= 22.04
      $xt_geoip_build_path = '/usr/libexec/xtables-addons/xt_geoip_build'
      # TODO: we might need a modified version of xt_geoip_build for 22.04,
      #       see the code above for 20.04
    }

    # Directory to store the binary database files
    file { '/usr/share/xt_geoip':
      ensure => directory
    }

    # Script to build the binary database
    file {"${localdir}/bin/load_geoip_dbip.sh":
      ensure    => present,
      mode      => '0700',
      owner     => 'root',
      group     => 'root',
      content   => template('puppet_infrastructure/fw_secure_extra/load_geoip_dbip.sh.erb'),
      require   => [ Package[$geoip_packages], File['/usr/share/xt_geoip'], ],
      notify    => Exec['Build_GeoIP_Database'],
      show_diff => false, # this file may contain the dbip key
    }
  
    # Execute the script to build the binary database 
    exec { 'Build_GeoIP_Database':
      user        => root,
      command     => "${localdir}/bin/load_geoip_dbip.sh",
      require     => File["${localdir}/bin/load_geoip_dbip.sh"],
      refreshonly => true,
    }
    
    # The cron job to update the database
    file {"${localdir}/bin/load_geoip_dbip_cron.sh":
      ensure  => present,
      mode    => '0755',
      owner   => 'root',
      group   => 'root',
      content => template('puppet_infrastructure/fw_secure_extra/load_geoip_dbip_cron.sh.erb'),
      require => File["${localdir}/bin/load_geoip_dbip.sh"],
    }
    cron { 'update_geoip_db':
      command  => "${localdir}/bin/load_geoip_dbip_cron.sh",
      user     => 'root',
      monthday => $dbip_update_monthday,
      hour     => '10',
      minute   => '0',
      require  => File["${localdir}/bin/load_geoip_dbip_cron.sh"]
    }

}
