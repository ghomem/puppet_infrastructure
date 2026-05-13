# Enforce GNOME screen lock policy using system dconf settings.
#
# This is intended for Ubuntu/GNOME desktops.
class puppet_infrastructure::gnome_lock_screen (
  Integer $screenlock_timeout_minutes = 5,
  Integer $screenlock_grace_seconds   = 0,
) {

  $screenlock_timeout_seconds = $screenlock_timeout_minutes * 60

  package { 'dconf-cli':
    ensure => installed,
  }

  file { '/etc/dconf':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { '/etc/dconf/profile':
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => File['/etc/dconf'],
  }

  file { '/etc/dconf/db':
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => File['/etc/dconf'],
  }

  file { '/etc/dconf/profile/user':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => File['/etc/dconf/profile'],
    content => "user-db:user\nsystem-db:local\n",
  }

  file { '/etc/dconf/db/local.d':
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => File['/etc/dconf/db'],
  }

  file { '/etc/dconf/db/local.d/locks':
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => File['/etc/dconf/db/local.d'],
  }

  file { '/etc/dconf/db/local.d/00-screenlock':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => @("DCONF"/L),
      [org/gnome/desktop/session]
      idle-delay=uint32 ${screenlock_timeout_seconds}

      [org/gnome/desktop/screensaver]
      lock-enabled=true
      lock-delay=uint32 ${screenlock_grace_seconds}
      | DCONF
    require => File['/etc/dconf/db/local.d'],
    notify  => Exec['dconf_update_screenlock'],
  }

  file { '/etc/dconf/db/local.d/locks/00-screenlock':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => @("LOCKS"/L),
      /org/gnome/desktop/session/idle-delay
      /org/gnome/desktop/screensaver/lock-enabled
      /org/gnome/desktop/screensaver/lock-delay
      | LOCKS
    require => File['/etc/dconf/db/local.d/locks'],
    notify  => Exec['dconf_update_screenlock'],
  }

  exec { 'dconf_update_screenlock':
    command     => '/usr/bin/dconf update',
    refreshonly => true,
    require     => Package['dconf-cli'],
  }
}
