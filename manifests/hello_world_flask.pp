define puppet_infrastructure::hello_world_flask (
  # The IP adress where the application is listening to incoming connections
  $ip_address = '0.0.0.0',
  # The port where the application is listening to incoming connections
  $port = 8080,
  # Set $uninstall to true to uninstall the application
  # This will not uninstall flask or gunicorn packages
  Boolean $uninstall = false,
  # Set the welcome message
  String $welcome_msg = 'Hello World!',
) {

  $localdir            = lookup('filesystem::localdir')

  include puppet_infrastructure::hello_world_flask_common

  if ($uninstall) {
     $directory_ensure = 'absent'
     $files_ensure = 'absent'
     $files_notify = []
     $systemd_file_notify = []
     $service_ensure = 'stopped'
     $service_enable = false
  } else {
     $directory_ensure = 'directory'
     $files_ensure = 'present'
     $files_notify = [ Exec["hello-world-flask-${title}-restart"], ]
     $systemd_file_notify = [ Exec["hello-world-flask-${title}-restart"], Exec["hello-world-flask-${title}-reload"], ]
     $service_ensure = 'running'
     $service_enable = true
  }

  # Directory for the application
  $app_dir = "${localdir}/hello_world_flask/$title"
  file { "${app_dir}":
    ensure => $directory_ensure,
    force  => true,
    mode   => '0644',
    owner  => 'root',
    group  => 'root',
  }

  # Deploy the python file with the application
  file { "${app_dir}/hello_world_flask.py":
    ensure  => $files_ensure,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => template('puppet_infrastructure/hello_world_flask/hello_world_flask.py.erb'),
    require => File[ "${app_dir}" ],
    notify  => $files_notify
  }

  # Deploy the python file with the WSGI file
  file { "${app_dir}/wsgi.py":
    ensure  => $files_ensure,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    source  => 'puppet:///modules/puppet_infrastructure/hello_world_flask/wsgi.py',
    require => File[ "${app_dir}/hello_world_flask.py" ],
    notify  => $files_notify
  }

  # the systemd startup script
  file { "/lib/systemd/system/hello-world-flask-${title}.service":
    ensure  => $files_ensure,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => template('puppet_infrastructure/hello_world_flask/hello-world-flask.service.erb'),
    notify  => $systemd_file_notify
  }

  # Make sure the systemd service is running
  service { "hello-world-flask-${title}":
    ensure   => $service_ensure,
    provider => 'systemd',
    enable   => $service_enable,
    require  => File[ "/lib/systemd/system/hello-world-flask-${title}.service", "${app_dir}/wsgi.py" ],
  }

  # This is just to restart and reload the service when the files change
  exec { "hello-world-flask-${title}-restart":
    command => "/usr/bin/systemctl restart hello-world-flask-${title}",
    refreshonly => true,
  }
  exec { "hello-world-flask-${title}-reload" :
    command => "/usr/bin/systemctl daemon-reload",
    refreshonly => true,
  }

}
