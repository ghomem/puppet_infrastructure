### Purpose ########
# This class provides a Puppet based user directory and CLI management interface called Hashman

### Outputs ########
# - pp_auth.py CLI interface
# - empty usable user database after first run

### Dependencies ###
#  packages: see below
#  hiera: see below
class puppet_infrastructure::hashman_base (
  # if true, the execution of /usr/local/<PREFIX>/bin/pp_auth.sh will print extra debug output
  $debug_mode = false,
) {

  $localdir   = lookup('filesystem::localdir')
  $hashmandir = lookup('hashman::bindir')
  $dbdir      = lookup('hashman::dbdir')
  $company    = lookup('hashman::company')
  $url        = join ( [ 'https://' , lookup('hashman::address') ] )
  $mailfrom   = lookup('hashman::mailfrom')
  $team       = lookup('hashman::team')
  $testenv    = lookup('hashman::testenv')

  # get minpassword len and relax pass requirements vars
  $minpasswordlen = lookup({ name => 'hashman::minpasswordlen' , default_value => '6' })
  $relaxp = lookup({ name => 'hashman::relaxpassword'  , default_value => true })

  # converting from Puppet boolean to Python boolean
  if ( $relaxp == true )
  {
    $relaxpassword = 'True'
  }
  else
  {
    $relaxpassword = 'False'
  }
  if ( $debug_mode == true )
  {
    $debug_mode_activated = 'True'
  }
  else
  {
    $debug_mode_activated = 'False'
  }

  $dbfiles = [ "${dbdir}/cnames.pp" , "${dbdir}/companies.pp", "${dbdir}/emails.pp", "${dbdir}/hashes.pp", "${dbdir}/keys.pp", "${dbdir}/ppsigs.pp", "${dbdir}/ppwrapped.pp" ]

  # dir for binaries, dir for database
  file { [ $hashmandir, $dbdir ]:
    ensure => directory,
    mode   => '0644',
    owner  => 'root',
    group  => 'root',
  }

  file { [ "${hashmandir}/common", "${hashmandir}/common/libhashman", "${hashmandir}/plugins", "${hashmandir}/plugins/1", "${hashmandir}/plugins/2", "${hashmandir}/plugins/3"  ]:
    ensure  => directory,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    require => File[ $hashmandir ],
  }

  file { "${hashmandir}/common/hashman_utils.py":
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    source  => 'puppet:///modules/puppet_infrastructure/hashman/common/hashman_utils.py',
    require => File[ "${hashmandir}/common" ],
  }

  file { "${hashmandir}/common/pp_auth.py":
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => template('puppet_infrastructure/hashman/pp_auth.py.erb'),
    require => File[ "${hashmandir}/common" ],
  }

  file { "${hashmandir}/common/libhashman/switch.py":
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => template('puppet_infrastructure/hashman/libhashman/switch.py.erb'),
    require => File[ "${hashmandir}/common/libhashman" ],
  }

  file { "${hashmandir}/common/libhashman/config.py":
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => template('puppet_infrastructure/hashman/libhashman/config.py.erb'),
    require => File[ "${hashmandir}/common/libhashman" ],
  }

  file { "${hashmandir}/common/libhashman/coding.py":
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => template('puppet_infrastructure/hashman/libhashman/coding.py.erb'),
    require => File[ "${hashmandir}/common/libhashman" ],
  }

  file { "${hashmandir}/common/libhashman/typeutils.py":
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => template('puppet_infrastructure/hashman/libhashman/typeutils.py.erb'),
    require => File[ "${hashmandir}/common/libhashman" ],
  }

  file { "${hashmandir}/common/libhashman/dbutils.py":
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => template('puppet_infrastructure/hashman/libhashman/dbutils.py.erb'),
    require => File[ "${hashmandir}/common/libhashman" ],
  }

  file { "${hashmandir}/common/libhashman/mailutils.py":
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => template('puppet_infrastructure/hashman/libhashman/mailutils.py.erb'),
    require => File[ "${hashmandir}/common/libhashman" ],
  }

  file { "${hashmandir}/common/libhashman/miscutils.py":
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => template('puppet_infrastructure/hashman/libhashman/miscutils.py.erb'),
    require => File[ "${hashmandir}/common/libhashman" ],
  }

  file { "${hashmandir}/common/libhashman/interface.py":
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => template('puppet_infrastructure/hashman/libhashman/interface.py.erb'),
    require => File[ "${hashmandir}/common/libhashman" ],
  }

  file { "${hashmandir}/common/libhashman/test.py":
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => template('puppet_infrastructure/hashman/libhashman/test.py.erb'),
    require => File[ "${hashmandir}/common/libhashman" ],
  }

  # shell wrapper to solve encoding issues #56
  file { "${localdir}/bin/pp_auth.sh":
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => template('puppet_infrastructure/hashman/pp_auth.sh.erb'),
    require => File[ "${localdir}/bin" ],
  }

  # initdb if necessary
  file { $dbfiles:
    ensure  => 'present',
    replace => 'no', # can't touch this!
    content => '',
    mode    => '0644',
    require => File[ $dbdir ],
  }

  package { [ 'python3-cracklib', 'python3-setproctitle', 'python3-openssl', 'python3-rsa', 'python3-prettytable' ]: ensure => present, }

}
