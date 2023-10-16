### Purpose ########
# This defined type is a helper that besides ensuring a config file also runs postmap when needed.
define puppet_infrastructure::postfix_smtp_base_config_file (
) {
  # Create a postfix hash config file and hash it

  # Get the name of the template to use
  $hash_template_name = basename($name)

  # Create/update the file to be hashed
  file {$name:
    ensure    => present,
    subscribe => Package['postfix'],
    # Ensure the exec is run
    notify    => [Exec["hash ${name}"], ],
    content   => template("puppet_infrastructure/postfix_smtp_base/${hash_template_name}.erb"),
    # Ensure it's owned by root:root
    owner     => 'root',
    group     => 'root',
    # Ensure only root can write
    mode      => 'u=rw,g=r,o=r',
  }
  # Hash the file and restart postfix
  exec {"hash ${name}":
    refreshonly => true,
    command     => "/usr/sbin/postmap ${name}",
    notify      => [Service['postfix'], ],
  }

}
