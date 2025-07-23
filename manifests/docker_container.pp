define puppet_infrastructure::docker_container (
  $image,
  $app_port = '',
  $host_port = '',
  $tag = 'latest',
  $ensure = 'present',
  $digest = '',
  $myorigin = '',
  $username = '',
  $token = '',
  $network = 'bridge',
  $env = [],
  $volumes = [],
) {

  $registry_url = split($image, '/')[0]
  $img_name     = $image

  if $host_port == '' {
    $myhost_port = $app_port
  } else {
    $myhost_port = $host_port
  }

  if $username != '' and $token != '' {
    if ! defined(Docker::Registry[$registry_url]) {
      docker::registry { $registry_url:
        username => $username,
        password => $token,
      }
    }
  }

  if $digest != '' {
    $image_id = "${img_name}@${digest}"
    docker::image { $image:
      ensure       => $ensure,
      image_digest => $digest,
    }
  } else {
    $image_id = "${img_name}:${tag}"
    docker::image { $image:
      ensure    => $ensure,
      image_tag => $tag,
    }
  }

  # Define the name for the docker run instance
  $container_name = $name

  # Always bind exposed ports to 127.0.0.1
  if $app_port != '' {
    $myapp_port = ["127.0.0.1:${myhost_port}:${app_port}"]
  } else {
    $myapp_port = []
  }

  if $volumes != [] {
    # collect the bit before ':' and keep only entries that don't look
    # like absolute/relative paths (i.e. are real named-volumes)
    $named_vols = unique(
      filter(
        map($volumes) |$v| { split($v, ':')[0] }
      ) |$n| { $n !~ /^\/|^\./ }
    )

    # Create named volumes with exec to avoid docker_volume provider errors on the first run
    if $named_vols != [] {
      $named_vols.each |String $vol| {
        exec { "mkvol-${vol}":
          command => "/usr/bin/docker volume create ${vol}",
          unless  => "/usr/bin/docker volume inspect ${vol}",
          path    => ['/usr/bin','/bin'],
          require => Class['docker'],
          before  => Docker::Run[$container_name],
        }
      }
    }
  }

  docker::run { $container_name:
    ensure                            => present,
    image                             => $image_id,
    env                               => $env,
    ports                             => $myapp_port,
    volumes                           => $volumes,
    remove_container_on_stop          => false,
    restart_service_on_docker_refresh => true,
    net                               => $network,
    subscribe                         => Docker::Image[$image],
  }
}
