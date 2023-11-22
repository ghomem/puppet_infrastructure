class puppet_infrastructure::letsencrypt_base_do (
  String $email,
  String $do_creds_file,
  String $do_api_token,
  Array[String] $domains,
  Boolean $automate_deployment        = false,
  Integer $renew_cron_hour            = 4,
  Integer $renew_cron_minute          = 0,
  Integer $deploy_cron_hour           = 5,
  Integer $deploy_cron_minute         = 0,
  Array[Integer] $renew_cron_monthday = [5,10,15,20,25],
){

  $major_release = $facts['os']['release']['major']

  if $major_release == '16.04' or $major_release == '18.04' {
    apt::ppa { 'ppa:certbot/certbot': }

    # letsencrypt plugin for DO
    package { 'letsencrypt DO plugin':
      name     => 'python3-certbot-dns-digitalocean',
      ensure   => 'installed',
      provider => 'apt',
      require  => Apt::Ppa['ppa:certbot/certbot'],  # ensures it is installed after the PPA is added
    }
  } else {
    # letsencrypt plugin for DO
    package { 'letsencrypt DO plugin':
      name     => 'python3-certbot-dns-digitalocean',
      ensure   => 'installed',
      provider => 'apt',
    }
  }

  # DO API token file location
  file { $do_creds_file:
    mode      => '600',
    owner     => 'root',
    group     => 'root',
    show_diff => false,
    content => template('puppet_infrastructure/letsencrypt/do-creds.ini.erb'),
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
    require                  => Package['letsencrypt DO plugin'],
  }


  $localdir        = lookup('filesystem::localdir')
  $bindir          = "${localdir}/bin"
  $certificatesdir = "/etc/letsencrypt/live"
  $ssldir          = "/etc/puppetlabs/puppet/extra_files/ssl"
  $domains_str     = join($domains,' ')

  # Script to deploy the certificates
  file {"${bindir}/deploy_mantained_certificates.sh":
    ensure    => present,
    mode      => '0700',
    owner     => 'root',
    group     => 'root',
    content   => template('puppet_infrastructure/letsencrypt/deploy_mantained_certificates.sh.erb'),
  }

  # Cronjob to run the scripts. The cronjob is set to present if the variable $automate_deployment is passed as true. Otherwise it is set to absent.
  if $automate_deployment {
    $cron_ensure = 'present'
  } else {
    $cron_ensure = 'absent'
  }

  cron { 'deploy_mantained_certificates':
    ensure   => $cron_ensure,
    minute   => $deploy_cron_minute,
    hour     => $deploy_cron_hour,
    monthday => $renew_cron_monthday,
    user     => 'root',
    command  => "${bindir}/deploy_mantained_certificates.sh"
  }
}
