node 'desktop-node01' {

  class {'puppet_infrastructure::node_base_desktop':
    apt_surface_list => $apt_surface_desktop,
    firewall_strict_purge => false,
    firewall_ignore_patterns => [ 'lxdbr0', 'docker' ],
  }

}

