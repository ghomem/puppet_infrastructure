# The purpose of this class is adding one of our server PPAs, staging or production
class puppet_infrastructure::server_ppa (
  Enum['production', 'staging', 'none'] $server_ppa = 'none',
) {

  if ( $server_ppa == 'production' ) {
    $server_ppa_name = 'ppa:solidangle/server'
  } elsif ( $server_ppa == 'staging' ) {
    $server_ppa_name = 'ppa:solidangle/server-staging'
  } else {
    $server_ppa_name = undef
  }

  if ( $server_ppa_name ) {
    apt::ppa{ "${server_ppa_name}": }
  }

}
