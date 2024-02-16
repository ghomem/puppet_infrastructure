#!/bin/bash
# usage example: sudo ./install-puppet-node.sh FQDN DOMAIN MASTER CUSTOMER

SWAPFILE=/swapfile

# Check if any swap is already in use
if [ -z "$(swapon --show)" ]; then
    if [ -n "$(cat /proc/1/environ | grep container)" ]; then
        # Create and configure swap file
        /bin/dd if=/dev/zero of=$SWAPFILE bs=1M count=1024
        /sbin/mkswap $SWAPFILE
        chmod 600 $SWAPFILE
        /sbin/swapon $SWAPFILE
        cp -f /etc/fstab /etc/fstab.orig
        grep $SWAPFILE /etc/fstab || echo "$SWAPFILE  swap  swap  defaults  0  0" >> /etc/fstab
    fi
fi

# Disable cloud-init and set the MTU to 1500 on AWS instances
touch /etc/cloud/cloud-init.disabled
echo "supersede interface-mtu 1500;" >> /etc/dhcp/dhclient.conf

# Ensure Perl is installed
if ! command -v perl &> /dev/null; then
    echo "Perl could not be found. Installing Perl..."
    if [ -f /etc/redhat-release ]; then
        # For RHEL/CentOS
        yum install -y perl
    else
        # For Debian/Ubuntu
        apt-get install -y perl
    fi
fi

cp -f /etc/sudoers /etc/sudoers.orig
# fix sudo path (this should work across CentOS and Ubuntu, you can grep afterwards to check with grep puppet /etc/sudoers)
perl -pi -e 's/^(Defaults\s*secure_path\s?=\s?\"?[^\"\n]*)(\"?)$/$1:\/opt\/puppetlabs\/bin$2/' /etc/sudoers

SETHOSTNAME=yes
START=no
UBUNTUREPOPKG=/tmp/puppetlabs-release-puppet5.deb
RHELREPOPKG=/tmp/puppetlabs-release-puppet5.rpm
UBUNTUREPOPKGURL=http://apt.puppetlabs.com/puppet5-release-bionic.deb
RHELREPOPKGURL=https://yum.puppet.com/puppet-release-el-$(rpm -E '%{rhel}').noarch.rpm
NODENAME=$1
DOMAIN=$2
NODECONF=/etc/puppetlabs/puppet/puppet.conf
PUPPETBIN=/opt/puppetlabs/bin/puppet
MASTER=$3
CUSTOMER=$4

#### main ####

if [ -z "$NODENAME" ] || [ -z "$DOMAIN" ]; then
    echo "Usage: $0 NODENAME DOMAIN [MASTER]"
    exit 1
fi

if [ -z "$MASTER" ]; then
    MASTER=puppet.$DOMAIN
fi

# set hostname
if [ "x$SETHOSTNAME" = "xyes" ]; then
    hostnamectl set-hostname $NODENAME
    grep "$NODENAME" /etc/hosts || echo "127.0.0.1 ${NODENAME}.${DOMAIN}" ${NODENAME} >> /etc/hosts
fi

# Detect OS and install Puppet 5
if [ -f /etc/redhat-release ]; then
    # RHEL/CentOS
    yum install -y wget
    wget -O $RHELREPOPKG $RHELREPOPKGURL
    yum install -y $RHELREPOPKG
    yum install -y puppet-agent
else
    # Ubuntu
    apt-get update
    apt-get install -y wget
    wget -O $UBUNTUREPOPKG $UBUNTUREPOPKGURL
    dpkg -i $UBUNTUREPOPKG
    apt-get update
    apt-get install -y puppet-agent
fi

# configurations and start puppet service
cp -f $NODECONF ${NODECONF}.orig
echo -e "[main]\nserver=${MASTER}\nnode_name=cert\ncertname=${NODENAME}\nlogdir=/var/log/puppet\nvardir=/var/lib/puppet\nssldir=/var/lib/puppet/ssl\nrundir=/var/run/puppet\nfactpath=\$vardir/lib/facter" > /etc/puppetlabs/puppet/puppet.conf

$PUPPETBIN resource service puppet ensure=running enable=true provider=systemd

if [ "x$START" = "xyes" ]; then
    systemctl enable puppet
    systemctl start puppet
else
    systemctl disable puppet
    systemctl stop puppet
fi

# Custom customer fact
mkdir -p /etc/facter/facts.d
echo "customer=$CUSTOMER" > /etc/facter/facts.d/facts.txt

$PUPPETBIN agent --test
