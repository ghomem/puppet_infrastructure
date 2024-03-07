#!/bin/bash
# usage example: sudo ./install-puppet-node.sh FQDN DOMAIN MASTER WAITFORCERT

SWAPFILE=/swapfile

# Check if any swap is already in use
if [ -z "$(swapon --show)" ]; then
    if [ -n "$(cat /proc/1/environ |grep container)" ]; then
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

cp -f /etc/sudoers /etc/sudoers.orig
# fix sudo path (this should work across CentOS and Ubuntu, you can grep afterwards to check with grep puppet /etc/sudoers)
perl -pi -e 's/^(Defaults\s*secure_path\s?=\s?\"?[^\"\n]*)(\"?)$/$1:\/opt\/puppetlabs\/bin$2/' /etc/sudoers

SETHOSTNAME=yes
START=no
REPOPKG=/tmp/puppetlabs-release-bionic.deb
REPOPKGURL=http://apt.puppetlabs.com/puppet5-release-bionic.deb
NODENAME=$1
DOMAIN=$2
NODECONF=/etc/puppetlabs/puppet/puppet.conf
PUPPETBIN=/opt/puppetlabs/bin/puppet
MASTER=$3
WAITFORCERT=$4

#### main ####

if [ -z $NODENAME ]; then
 echo usage: $0 NODENAME DOMAIN [MASTER]
 exit
fi

if [ -z $DOMAIN ]; then
 echo usage: $0 NODENAME DOMAIN [MASTER]
 exit
fi

if [ -z $MASTER ]; then
 MASTER=puppet.$DOMAIN
fi

# set hostname
if [ x$SETHOSTNAME = 'xyes' ]; then
 hostnamectl set-hostname  $NODENAME
 grep $NODENAME /etc/hosts || echo "127.0.0.1 ${NODENAME}.${DOMAIN}" ${NODENAME} >> /etc/hosts
fi

apt-get update
apt-get install -y wget

wget -O $REPOPKG $REPOPKGURL
dpkg -i $REPOPKG

apt-get update
apt-get install -y ntp
apt-get install -y puppet-agent

# configurations  and start puppet service
cp -f $NODECONF ${NODECONF}.orig
echo -e "[main]\nserver=${MASTER}\nnode_name=cert\ncertname=${NODENAME}\nlogdir=/var/log/puppet\nvardir=/var/lib/puppet\nssldir=/var/lib/puppet/ssl\nrundir=/var/run/puppet\nfactpath=$vardir/lib/facter" > /etc/puppetlabs/puppet/puppet.conf

$PUPPETBIN resource service puppet ensure=running enable=true provider=systemd

if [ x$START = 'xyes' ]; then
  systemctl enable puppet.service
  systemctl start puppet.service
else
  systemctl disable puppet.service
  systemctl stop puppet.service
fi

if [ -z $WAITFORCERT ]; then
  EXTRA_ARGS=
else
  EXTRA_ARGS="--waitforcert $WAITFORCERT"
fi

$PUPPETBIN agent --test $EXTRA_ARGS
