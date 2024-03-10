class puppet_infrastructure::hello_world_web_docker (
  $revision = 'latest',
  $myport = ''
) {

  $img_name = 'digitalocean/flask-helloworld'

  docker::image { $img_name:
    ensure    => present,
    image_tag => $revision,
  }

  # runs the container and creates service
  docker::run { 'flask-helloworld':
    ensure    => present,
    image     => $img_name,
    env       => [ ],
    ports     => [ "${myport}:5000" ],
    subscribe => Docker::Image[ $img_name ],
  }

}
