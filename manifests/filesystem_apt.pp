### Purpose ########
# This class provides helper scripts for apt based system updates

class puppet_infrastructure::filesystem_apt (
  # list of critical surface packages, if empty it will use a builtin default list
  Array[String] $apt_surface_list = [],
  # this parameter must be set to:
  # - 'true' when using this class for a server
  # - 'false' when using this class for a desktop
  $server_mode = true,
  # Relevant updates method
  # 0 - no relevant updates support
  # 1 - reseved for an old method, no longer supported
  # 2 - method based on analysis of the oval data provided by Ubuntu, see: https://ubuntu.com/security/oval
  Integer $relevant_updates_method = 2,
  # Select if we want to take into account kernel updates or not
  # This option only works if we use the relevant updates method 2 above
  Boolean $relevant_updates_no_kernel = false,
) {

  $localdir = lookup('filesystem::localdir')

  # wrapper for apt-get install the avoid undesired installs
  file { "${localdir}/bin/apt-update-pkg.sh":
  mode    => '0755',
  owner   => 'root',
  group   => 'root',
  source  => 'puppet:///modules/puppet_infrastructure/apt/apt-update-pkg.sh',
  require => File[ "${localdir}/bin" ],
  }

  # security surface default lists
  $apt_surface_server = ['openssh-server', 'openssh-client', 'openssh-sftp-server',
                         'openssl', 'libssl1.1',
                         'libudev1', 'ca-certificates',
                         'vim', 'vim-runtime', 'vim-common',
                         'coreutils', 'gzip', 'less', 'multitail',
                         'util-linux', 'openvpn',
                         'nginx-core', 'nginx-extras',
                         'postfix', 'dovecot-core',]
  $apt_surface_desktop = ['openssh-server', 'openssh-client', 'openssh-sftp-server',
                          'openssl', 'libssl1.1',
                          'libudev1', 'ca-certificates',
                          'vim', 'vim-runtime', 'vim-common',
                          'coreutils', 'gzip', 'less', 'multitail',
                          'util-linux', 'openvpn',
                          'firefox', 'firefox-locale-en',
                          'flashplugin-installer']

  # select the proper default list if $apt_surface_list is empty
  if ( $apt_surface_list == []) {
    if ( $server_mode ) {
      $_apt_surface_list = join($apt_surface_server, " ")
    } else {
      $_apt_surface_list = join($apt_surface_desktop, " ")
    }
  } else {
    $_apt_surface_list = $apt_surface_list
  }

  # security surface updates
  file { "${localdir}/bin/apt-update-surface.sh":
  mode    => '0755',
  owner   => 'root',
  group   => 'root',
  content => template('puppet_infrastructure/apt/apt-update-surface.sh.erb'),
  require => File[ "${localdir}/bin" ],
  }

  if ( ! $server_mode ) {
    # security surface updates for DESKTOPS - just a compatibility symlink to the previous file
    file { "${localdir}/bin/apt-update-surface-desktop.sh":
      mode    => '0755',
      owner   => 'root',
      group   => 'root',
      ensure  => 'link',
      target  => "${localdir}/bin/apt-update-surface.sh",
      require => File[ "${localdir}/bin/apt-update-surface.sh" ],
    }
  }

  # kernel updates
  file { "${localdir}/bin/apt-update-kernel.sh":
  mode    => '0755',
  owner   => 'root',
  group   => 'root',
  source  => 'puppet:///modules/puppet_infrastructure/apt/apt-update-kernel.sh',
  require => File[ "${localdir}/bin" ],
  }

  # full updates
  file { "${localdir}/bin/apt-update-dist.sh":
  mode    => '0755',
  owner   => 'root',
  group   => 'root',
  source  => 'puppet:///modules/puppet_infrastructure/apt/apt-update-dist.sh',
  require => File[ "${localdir}/bin" ],
  }

  # make sure the only output is the package list to be used below
  $check_apt_silent='1'
  $check_apt_debug='0'

  # used for the script to write the packages to update list
  $update_cache_dir = '/var/lib/apt-check-updates'

  # define what prio is assigned for issues which prio is not determinable for some reason
  $default_prio = 'Medium'

  # this is a template because it calls a python helper at ${localdir}/bin
  if ($relevant_updates_method == 0) {
    #No relevant updates support, do nothing
  } elsif ($relevant_updates_method == 2) {

    # install openscap scanner package
    $major_release = $facts['os']['release']['major']

    if $major_release == '24.04' {
      $openscap_pkg = 'openscap-scanner'
    }
    else {
      # 20.04 and 22.04
      $openscap_pkg = 'libopenscap8'
    }

    package { $openscap_pkg: ensure => 'installed', }

    # install script to find out packages to update using the oscap scanner
    file { "${localdir}/bin/get-relevant-updates-list":
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    source  => 'puppet:///modules/puppet_infrastructure/apt/get-relevant-updates-list',
    require => File[ "${localdir}/bin" ]
    }

    # check if we want kernel updates or not
    if ($relevant_updates_no_kernel) {
      $apt_check_updates_no_kernel = 1
    } else {
      $apt_check_updates_no_kernel = 0
    }

    # wrapper script that will put a list of packages to update (one per-line)
    # in /var/lib/apt-check-updates/list
    # this script will download the oval xml file and execute the script above
    file { "${localdir}/bin/apt-check-updates.sh":
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => template('puppet_infrastructure/apt/apt-check-updates-v2.sh.erb'),
    require => File[ "${localdir}/bin" ]
    }

  } else {

    fail("Invalid relevant_updates_method = ${relevant_updates_method}")

  }

  $prio_threshold   = lookup( { name => [ "${clientcert}::filesystem_apt::prio_threshold", 'filesystem_apt::prio_threshold' ], default_value => 'High' } )
  $check_hour   = lookup( { name => [ "${clientcert}::filesystem_apt::checkhour", 'filesystem_apt::checkhour' ], default_value => '0' } )
  $check_min    = lookup( { name => [ "${clientcert}::filesystem_apt::checkmin",  'filesystem_apt::checkmin'  ], default_value => '0' } )

  # because the execution is slow we have a cronjob that keeps the update list available for priorities >= $prio_threshold
  # this will allow integration with monitoring systems

  cron { 'apt_check_updates':
  command  => "${localdir}/bin/apt-check-updates.sh ${prio_threshold}",
  user     => root,
  monthday => '*',
  hour     => $check_hour,
  minute   => $check_min,
  }

  file { $update_cache_dir:
  ensure => directory,
  mode   => '0755'
  }

  # script to install relevant security updates, using the list created by
  # apt-check-updates.sh deployed above
  file { "${localdir}/bin/apt-update-relevant.sh":
  mode    => '0755',
  owner   => 'root',
  group   => 'root',
  content => template('puppet_infrastructure/apt/apt-update-relevant.sh.erb'),
  require => File[ "${localdir}/bin" ],
  }

}
