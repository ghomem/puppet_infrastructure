class puppet_infrastructure::letsencrypt_base (
  String $email,
  String $dns_creds_file              = "${lookup('filesystem::etcdir')}/dns-creds.ini",
  String $dns_api_token,
  Array[String] $domains,
  Boolean $automate_deployment        = true,
  Integer $renew_cron_hour            = 4,
  Integer $renew_cron_minute          = 0,
  Integer $deploy_cron_hour           = 5,
  Integer $deploy_cron_minute         = 0,
  Array[Integer] $renew_cron_monthday = [5,10,15,20,25],
  Enum['digitalocean', 'hetzner'] $provider,
){

  if $provider == 'digitalocean' {
    $package_name     = 'python3-certbot-dns-digitalocean'
    $package_provider = 'apt'
    $api_property_str = 'dns_digitalocean_token'
    $required_packages = []
  } else {
    $package_name     = 'certbot-dns-hetzner'
    $package_provider = 'pip'
    $api_property_str = 'dns_hetzner_api_token'
    $required_packages = ['Package[python3 pip]']

    # python3 pip required for intalling certbot-dns-hetzner
    package { 'python3 pip':
      name     => 'python3-pip',
      ensure   => 'installed',
      provider => 'apt',
    }
  }

  # letsencrypt plugin
  package { 'letsencrypt plugin':
    name     => $package_name,
    ensure   => 'installed',
    provider => $package_provider,
    require  => $required_packages,
  }

  # dns API token file location
  file { $dns_creds_file:
    mode      => '600',
    owner     => 'root',
    group     => 'root',
    show_diff => false,
    content => template('puppet_infrastructure/letsencrypt/dns-creds.ini.erb'),
  }

  class { 'letsencrypt':
    email                    => $email,
    # run renew cron at 4AM every 5th,10th,15th,20th,25th of the month
    renew_cron_ensure        => present,
    renew_cron_hour          => $renew_cron_hour,
    renew_cron_minute        => $renew_cron_minute,
    renew_cron_monthday      => $renew_cron_monthday,
    # reload NGINX (no downtime) after renewing certs
    renew_post_hook_commands => 'service nginx reload',
    require                  => Package['letsencrypt plugin'],
  }


  $localdir        = lookup('filesystem::localdir')
  $bindir          = "${localdir}/bin"
  $certificatesdir = "/etc/letsencrypt/live"
  $ssldir          = "/etc/puppetlabs/puppet/extra_files/ssl"
  $domains_str     = join($domains,' ')

  # Script to deploy the certificates
  file {"${bindir}/deploy_maintained_certificates.sh":
    ensure    => present,
    mode      => '0700',
    owner     => 'root',
    group     => 'root',
    content   => template('puppet_infrastructure/letsencrypt/deploy_maintained_certificates.sh.erb'),
  }

  # Cronjob to run the scripts. The cronjob is set to present if the variable $automate_deployment is passed as true. Otherwise it is set to absent.
  if $automate_deployment {
    $cron_ensure = 'present'
  } else {
    $cron_ensure = 'absent'
  }

  cron { 'deploy_maintained_certificates':
    ensure   => $cron_ensure,
    minute   => $deploy_cron_minute,
    hour     => $deploy_cron_hour,
    monthday => $renew_cron_monthday,
    user     => 'root',
    command  => "${bindir}/deploy_maintained_certificates.sh"
  }
}
