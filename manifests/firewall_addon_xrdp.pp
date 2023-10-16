### Purpose ########
# This class opens firewall ports so sysadmins
# are able to access machines with the helpdesk feature
# Ref: https://bitbucket.org/asolidodev/is-desktop8/wiki/Helpdesk%20connection
class puppet_infrastructure::firewall_addon_xrdp {
    
  firewall { '3389 allow xrdp':
    proto  => 'tcp',
    dport  => 3389,
    action => 'accept',
  }

  firewall { '3389 allow xrdp to vnc ipv6':
    proto    => 'tcp',
    iniface  => 'lo',
    dport    => 5900,
    action   => 'accept',
    provider => 'ip6tables'
  }

# The behind this rule is the following:
#
# xrdp communicates with VNC initially using IPv6 and only if that fails IPv4 is used
#
# However DROPpping IPv6 traffic with iptables like we usually do, is not seen as a failure
# from the XRDP standpoint. When IPv6 traffic is DROPped the connection to VNC does not work
#
# https://github.com/neutrinolabs/xrdp/issues/1596
#
# To fix that we open INPUT with dport 5900 in lo so xrdp can communicate with vnc.
# xrdp will initiate a connection from lo:XXXX with destionation lo:5900
# which will be accepted by the INPUT rule. Although vnc will respond from
# lo:5900 to lo:XXXX and this comunication will not be accepted if the ESTABLISHED
# rule does not exist
  firewall { '003 Allow established ipv6':
    proto    => 'tcp',
    state    => ['ESTABLISHED'],
    sport    => '5900',
    action   => 'accept',
    provider => 'ip6tables',
  }

}
