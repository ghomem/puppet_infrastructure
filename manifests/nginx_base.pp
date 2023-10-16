### Purpose ########
# Our base nginx class installs nginx and performs configurations common to all servers (aka vhosts)

### Usage ########
# For default behavior:
# include puppet_infrastructure::nginx_base
# Example for custom behavior:
# class {'puppet_infrastructure::nginx_base':
#   my_configs => {
#     names_hash_bucket_size => 128,
#     proxy_connect_timeout  => '50s',
#   },
#   ad_hoc_configs => [
#     "fastcgi_buffers 4 256k;",
#     "fastcgi_buffer_size 128k;",
#   ],
# }

# WARNING We changed the way this class is declared.
# If you were declaring nodes using any of these previous attributes of this class, they should now go into the my_configs hash:
## my_package_name
## worker_processes
## worker_connections
## worker_rlimit_nofile
# and these should now go into strings in the ad_hoc_configs array:
## proxy_buffers
## proxy_buffer_size

class puppet_infrastructure::nginx_base (
  # Using a non-standard DH group with greater bits protects against state actors and leaks from them.
  # As mentioned in https://weakdh.org/sysadmin.html:
  # "We further estimate that an academic team can break a 768-bit prime and that a nation-state can break a 1024-bit prime."
  # Using a 4096 bit group looks like overkill at this moment (considering the need to enter a site quickly) as it is 4x the 1024-bit.
  # We choose to follow https://weakdh.org/sysadmin.html: "We recommend that you generate a 2048-bit group".
  # We do this even if the Qualys test gives a (slightly) lower rating when a 2048-bit group is used (compared to the rating with a 4096-bit group).
  $dh_params_bits = 2048,
  # This is optional and it can be used to:
  # - add log formats that are not in this class (the ones of $log_formats_main)
  # - override log formats in use in this class (if you use one of the names in $log_formats_main)
  $log_formats_additional = {},
  # This $my_configs hash is used to acess all the parameters from the module:
  # https://github.com/voxpupuli/puppet-nginx/blob/v0.13.0/manifests/init.pp
  # Four parameters from previous versions were removed
  # because they had default behavior from the puppet nginx module,
  # they are Integer $worker_connections= 1024,
  # Integer $worker_rlimit_nofile =  1024,
  # String $proxy_buffers = '32 4k',
  # and String $proxy_buffer_size = '8k',
  # (as can be seen by following the link above).
  # You should probably avoid passing $log_format to this hash,
  # because it will override default behavior, instead you should use
  # the $log_formats_additional hash parameter seen above.
  # Issue #149 In case of long FQDN, pass names_hash_bucket_size to the hash,
  # which accepts values in powers of 2, the default value is 64.
  Hash $my_configs = {},
  # This $ad_hoc_configs array exists to expose nginx configs
  # that don't exist in the puppet nginx module and should be used
  # only for that purpose. It uses nginx configuration syntax
  Array $ad_hoc_configs = [],
) {

  # Parameters
  $log_formats_main = {
    # gaming platform suggestion addapted to oneline
    'main' => '[$time_local] server_name: $server_name, remote_addr: $remote_addr, forwarded_for: $http_x_forwarded_for, request: $request, request_time: $request_time, upstream_addr: $upstream_addr, upstream_response_time: $upstream_response_time, upstream_cache_status: $upstream_cache_status, upstream_status: $upstream_status, status: $status, body_bytes_sent: $body_bytes_sent, http_referer: $http_referer, http_user_agent: $http_user_agent',
    'compact' => '$remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent" "$http_x_forwarded_for" $upstream_status $upstream_addr',
  }

  # Get the log formats to be used
  # Beware the merge function behavior:
  # "When there is a duplicate key, the key in the rightmost hash takes precedence."
  $log_formats = merge(
    $log_formats_main,
    $log_formats_additional,
  )

  $default_configs = {
    manage_repo       => false,
    # This is package name works on ubuntu 16.04 (where it is a metapackage for nginx-core) and on CentOS 6
    package_name      => 'nginx',
    # auto will make nginx try to detect and use the CPUs of the host
    worker_processes  => 'auto',
    # disable 'emitting nginx version on error pages and in the “Server” response header field.'
    server_tokens     => 'off',
    log_format        => $log_formats,
    nginx_cfg_prepend => {'include' => '/etc/nginx/modules-enabled/*'},
  }

  # Beware the merge function behavior:
  # "When there is a duplicate key, the key in the rightmost hash takes precedence."
  $configs = merge(
    $default_configs,
    $my_configs,
  )

  # we install nginx from the distribution repository
  # We use the splat operator (*) which expands the $configs hash,
  # each key becomes a parameter of the class
  # and the according value becomes the parameter value
  # https://puppet.com/docs/puppet/5.3/lang_resources_advanced.html#setting-attributes-from-a-hash
  if ( $facts['os']['name'] == 'Ubuntu' ) {
    class { 'nginx':
      * => $configs,
      require => Exec['apt_update'], # we might be installing nginx from a PPA
    }
  } else {
    class { 'nginx':
      * => $configs,
    }
  }

  if ($ad_hoc_configs == []) {
    $config_ensure = 'absent'
    $ad_hoc_content = ''
  } else {
    $config_ensure = 'present'
    $ad_hoc_content = join($ad_hoc_configs, "\n")
  }

  #file in conf.d for adhoc configs
  file {'/etc/nginx/conf.d/puppet_infrastructure.conf':
    ensure  => $config_ensure,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "${ad_hoc_content}\n",
    notify  => Service[ 'nginx' ],
  }

  # create custom DH group
  $nginx_conf_dir = '/etc/nginx/'
  ## we are not creating '/etc/nginx' here because that resource already exists in the nginx class,
  ## therefore declaring it here again would result in puppet agent run errors
  #file {"$nginx_conf_dir":
  #  ensure  => 'directory',
  #  mode    => '0755',
  #  owner   => 'root',
  #  group   => 'root',
  #}
  $base_dh_params = '/etc/nginx/dhparams.pem'
  exec {"Generate a new ${dh_params_bits}-bit Diffie-Hellman group":
    command => "/usr/bin/openssl dhparam -out ${base_dh_params} ${dh_params_bits} && chmod u=rw,g=r,o= ${base_dh_params}",
    creates => $base_dh_params,
    # we can't require the 'nginx' class here because it would cause a dependency loop
    require => File["$nginx_conf_dir"],
  }

}
