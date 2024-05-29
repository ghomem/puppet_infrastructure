### Purpose ########
# This class defines an Adagios sysmon user

### Dependencies ###
# modules: leinaddm-htpasswd
define puppet_infrastructure::user_sysmon( $myname = 'Dummy Dummier', $myhash = '', $myemail = 'dummy@localhost', $mygrouplist = [ ] ) {

  $myusername = $title

  # from module leinaddm-htpasswd
  $htpasswd_file = '/etc/thruk/htpasswd'
  htpasswd { $myusername : cryptpasswd => $myhash, target => $htpasswd_file }

  file { "/etc/naemon/conf.d/contacts/${myusername}.cfg":
  mode    => '0664',
  owner   => 'naemon',
  group   => 'naemon',
  content => template('puppet_infrastructure/users/sysmon_contact.erb'),
  }

}

