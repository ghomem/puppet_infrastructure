### Purpose ########
# This class provides a desktop-safe IPv6 DROP policy.
#
# It keeps IPv6 INPUT and FORWARD closed by default, but explicitly allows
# IPv6 loopback traffic on lo. This is required on desktops because some local
# GUI/session components may use ::1 during login. Silently dropping ::1 can
# cause login/session delays.

### Dependencies ###
#  modules: puppetlabs-firewall
class puppet_infrastructure::firewall_ipv6_drop_policy_desktop {

  firewall { '000 accept all IPv6 to lo interface':
    chain    => 'INPUT',
    proto    => 'all',
    iniface  => 'lo',
    action   => accept,
    provider => 'ip6tables',
  }

  firewallchain { 'FORWARD:filter:IPv6': ensure => present, purge => true, policy => drop, }
  firewallchain { 'INPUT:filter:IPv6':   ensure => present, purge => true, policy => drop, }

}
