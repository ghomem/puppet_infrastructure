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
  $env = []
) {
  $registry_url = split($image, '/')[0]
  $img_name = $image

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

  # Define the port configuration
  if $app_port != '' {
    $myapp_port = ["${myhost_port}:${app_port}"]
  } else {
    $myapp_port = []
  }

  docker::run { $container_name:
    ensure                            => present,
    image                             => $image_id,
    env                               => $env,
    ports                             => $myapp_port,
    remove_container_on_stop          => false,
    restart_service_on_docker_refresh => true,
    net                               => $network,
    subscribe                         => Docker::Image[$image],
  }
}
