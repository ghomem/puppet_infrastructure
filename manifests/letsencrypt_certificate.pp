define puppet_infrastructure::letsencrypt_certificate (
  String  $domain,
  String  $credentials_path = "${lookup('filesystem::etcdir')}/dns-creds.ini",
  String  $certificate_path = '',
  Boolean $include_root = false,
  Enum['digitalocean', 'hetzner'] $provider,
) {
  if ( ! empty($certificate_path) ) {
    $final_certificate_path = $certificate_path
  } else {
    $final_certificate_path = $domain
  }

  # inlude the root domain in the request
  if ( $include_root == true ) {
    # according to the docs splitting with a special char requires escaping
    $components  = split($domain, '\.')
    $root_domain = join($components[1,-1], '.')
    $domain_list = [$domain, $root_domain]
  }
  else {
    $domain_list = [$domain]
  }

  if $provider == 'digitalocean' {
    $additional_args = ['--dns-digitalocean', "--dns-digitalocean-credentials ${credentials_path}"]
  } else {
    $additional_args = ['--authenticator dns-hetzner', "--dns-hetzner-credentials ${credentials_path}"]
  }

  # the certificates are stored in /etc/letsencrypt/live/${final_certificate_path}
  letsencrypt::certonly { $final_certificate_path:
    domains         => $domain_list,
    custom_plugin   => true,  # removes the -a argument, add the other arguments with additional_args
    additional_args => $additional_args,
  }
}
