### Purpose ########
# This class provides a caching nameserver server using bind

# allowed_networks is an array of networks with bitmask. Example ['192.168.1.0/24', '192.168.5.0/24']
class puppet_infrastructure::caching_nameserver ( Array $allowed_networks = [] ){

    if ( $facts['os']['family'] == 'RedHat' ){

        $package_name = 'bind'
        $service_name = 'named'
        $conf_file    = '/etc/named.conf'
        $directory    = '/var/named'

    }
    else {

        $package_name = 'bind9'
        $service_name = 'named'
        $conf_file    = '/etc/bind/named.conf.options'
        $directory    = '/var/cache/bind'
    }

    package { 'bind':
        ensure => present,
        name   => $package_name,
    }

    service { $service_name:
        ensure  => 'running',
        require => Package['bind'],
    }

    file { $conf_file :
        owner   => root,
        group   => root,
        mode    => '0644',
        content => template('puppet_infrastructure/bind/named.conf.options.erb'),
        notify  => Service[ $service_name ],
    }

}
