### PURPOSE ###
# the purpose of this class is to setup a oneshot service
# to execute a puppet run in the boot sequence
# this need is expposed here: https://bitbucket.org/asolidodev/puppet_infrastructure/issues/287/make-sure-that-there-is-a-puppet-run-on

 class puppet_infrastructure::puppet_boot_run(){

    $localbindir = lookup('filesystem::bindir')
    $boot_run_script = "${localbindir}/puppet_boot_run.sh"

    file { $boot_run_script:
        ensure => present,
        owner  => 'root',
        group  => 'root',
        mode   => '0750',
        source => ('puppet:///modules/puppet_infrastructure/etc/puppet_boot_run.sh')
    }

    file { '/etc/systemd/system/puppet_boot_run.service':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('puppet_infrastructure/etc/puppet_boot_run.service.erb'),
        notify  => Exec[ 'Reload Systemctl Daemon for puppet boot run' ]
    }

    exec { 'Reload Systemctl Daemon for puppet boot run' :
        name        => '/bin/systemctl daemon-reload',
        refreshonly => true,
    }

    service { 'puppet_boot_run':
        enable => true
    }

}
