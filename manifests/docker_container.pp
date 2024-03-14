define puppet_infrastructure::docker_container (
  $image,
  $tag = 'latest',
  $digest = '',
  $myorigin = '',
  $myport = '',
  $username = '',
  $token = '',
  $env = []
) {
  $registry_url = split($image, '/')[0]
  $img_name = $image

  if $username != '' and $token != '' {
    if ! defined(Docker::Registry[$registry_url]) {
      docker::registry { $registry_url:
        username => $username,
        password => $token,
      }
    }
  }

  if $digest != '' {
    docker::image { $img_name:
      ensure    => present,
      image_digest => $digest,
    }
    $image_id = "${img_name}@${digest}"
  } else {
    docker::image { $img_name:
      ensure    => present,
      image_tag => $tag,
    }
    $image_id = "${img_name}:${tag}"
  }

  # Define the name for the docker run instance
  $container_name = $name

  # Define the port configuration
  if $myport {
    $app_port = ["${myport}:${myport}"]
  } else {
    $app_port = []
  }

  docker::run { $container_name:
    ensure                            => present,
    image                             => $image_id,
    env                               => $env,
    ports                             => $app_port,
    remove_container_on_stop          => false,
    restart_service_on_docker_refresh => true,
    subscribe                         => Docker::Image[$img_name],
  }
}
