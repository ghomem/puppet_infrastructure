#!/bin/bash

# Function definitions

function print_usage ()
{
  echo "Usage: $0 [--debug] NODENAME DOMAIN [MASTER] [WAITFORCERT]"
}

function handle_error () {
    rc=$1
    err_message=$2

    if [ "0" != "$rc" ]; then
        print_error "$err_message"
        exit $rc
    fi
}

function print_status () {
    local message=$1
    echo -e "\033[1;32m$message\033[0m"
}

function print_error () {
    local message=$1
    echo -e "\033[1;31m$message\033[0m"
}

function print_debug () {
    if [ "$DEBUG" = "yes" ]; then
        echo -e "$1"
    fi
}

function run_cmd () {
    local cmd="$1"
    local err_message="$2"
    if [ "$DEBUG" = "yes" ]; then
        eval $cmd
    else
        eval $cmd > /dev/null 2>&1
    fi
    handle_error $? "$err_message"
}

# Initialize DEBUG to no
DEBUG=no

# Process options
while [ "$1" != "" ]; do
    case $1 in
        --debug )           DEBUG=yes
                            ;;
        -h | --help )       print_usage
                            exit
                            ;;
        * )                 break
                            ;;
    esac
    shift
done

# Assign positional arguments
NODENAME=$1
DOMAIN=$2
MASTER=$3
WAITFORCERT=$4

if [ -z "$NODENAME" ] || [ -z "$DOMAIN" ]; then
    print_error "NODENAME and DOMAIN are required."
    print_usage
    exit 1
fi

if [ -z "$MASTER" ]; then
    MASTER=puppet.$DOMAIN
fi

SETHOSTNAME=yes
START=no
NODECONF=/etc/puppetlabs/puppet/puppet.conf
PUPPETBIN=/opt/puppetlabs/bin/puppet
SWAPFILE=/swapfile

print_status "Checking if swap is already in use..."

if [ -z "$(swapon --show)" ]; then
    if grep -q container /proc/1/environ; then
        print_status "No swap detected and running inside a container. Creating swap file..."

        run_cmd "/bin/dd if=/dev/zero of=$SWAPFILE bs=1M count=1024" "Failed to create swap file"
        run_cmd "/sbin/mkswap $SWAPFILE" "Failed to set up swap file"
        run_cmd "chmod 600 $SWAPFILE" "Failed to set permissions on swap file"
        run_cmd "/sbin/swapon $SWAPFILE" "Failed to enable swap file"

        run_cmd "cp -f /etc/fstab /etc/fstab.orig" "Failed to backup /etc/fstab"
        grep $SWAPFILE /etc/fstab > /dev/null 2>&1 || echo "$SWAPFILE  swap  swap  defaults  0  0" >> /etc/fstab
        handle_error $? "Failed to update /etc/fstab"
    else
        print_status "No swap detected but not inside a container. Skipping swap file creation."
    fi
else
    print_status "Swap is already in use."
fi

print_status "Disabling cloud-init and setting MTU to 1500..."

run_cmd "touch /etc/cloud/cloud-init.disabled" "Failed to disable cloud-init"
echo "supersede interface-mtu 1500;" >> /etc/dhcp/dhclient.conf
handle_error $? "Failed to set MTU in dhclient.conf"

if ! command -v perl &> /dev/null; then
    print_status "Perl could not be found. Installing Perl..."
    if [ -f /etc/redhat-release ]; then
        # For RHEL/CentOS
        run_cmd "yum install -y perl" "Failed to install Perl"
    else
        # For Debian/Ubuntu
        run_cmd "apt-get update" "Failed to update apt-get"
        run_cmd "apt-get install -y perl" "Failed to install Perl"
    fi
else
    print_status "Perl is already installed."
fi

print_status "Backing up /etc/sudoers and fixing secure_path..."

run_cmd "cp -f /etc/sudoers /etc/sudoers.orig" "Failed to backup /etc/sudoers"
perl -pi -e 's/^(Defaults\s*secure_path\s?=\s?\"?[^\"\n]*)(\"?)$/$1:\/opt\/puppetlabs\/bin$2/' /etc/sudoers

if [ "x$SETHOSTNAME" = "xyes" ]; then
    print_status "Setting hostname to $NODENAME..."

    run_cmd "hostnamectl set-hostname $NODENAME" "Failed to set hostname"
    grep "$NODENAME" /etc/hosts > /dev/null 2>&1 || echo "127.0.0.1 ${NODENAME}.${DOMAIN} ${NODENAME}" >> /etc/hosts
    handle_error $? "Failed to update /etc/hosts"
fi

print_status "Detecting OS and installing Puppet agent..."

if [ -f /etc/redhat-release ]; then
    RHELREPOPKGURL=https://yum.puppet.com/puppet-release-el-$(rpm -E '%{rhel}').noarch.rpm
    RHELREPOPKG=/tmp/puppetlabs-release-puppet5.rpm
    # RHEL/CentOS
    run_cmd "yum install -y wget" "Failed to install wget"
    run_cmd "wget -O $RHELREPOPKG $RHELREPOPKGURL" "Failed to download Puppet repo package"
    run_cmd "yum install -y $RHELREPOPKG" "Failed to install Puppet repo package"
    run_cmd "yum install -y puppet-agent" "Failed to install Puppet agent"
else
    UBUNTUREPOPKGURL=http://apt.puppetlabs.com/puppet5-release-bionic.deb
    UBUNTUREPOPKG=/tmp/puppetlabs-release-puppet5.deb
    # Ubuntu
    run_cmd "apt-get update" "Failed to update apt-get"
    run_cmd "apt-get install -y wget" "Failed to install wget"
    run_cmd "wget -O $UBUNTUREPOPKG $UBUNTUREPOPKGURL" "Failed to download Puppet repo package"
    run_cmd "dpkg -i $UBUNTUREPOPKG" "Failed to install Puppet repo package"
    run_cmd "apt-get update" "Failed to update apt-get after installing Puppet repo"
    run_cmd "apt-get install -t bionic -y puppet-agent" "Failed to install Puppet agent"
fi

print_status "Configuring Puppet agent..."

run_cmd "cp -f $NODECONF ${NODECONF}.orig" "Failed to backup puppet.conf"

cat > /etc/puppetlabs/puppet/puppet.conf <<EOL
[main]
server=${MASTER}
node_name=cert
certname=${NODENAME}
logdir=/var/log/puppet
vardir=/var/lib/puppet
ssldir=/var/lib/puppet/ssl
rundir=/var/run/puppet
factpath=\$vardir/lib/facter
EOL
handle_error $? "Failed to create puppet.conf"

print_status "Starting Puppet service..."

run_cmd "$PUPPETBIN resource service puppet ensure=running enable=true provider=systemd" "Failed to start Puppet service"

if [ "x$START" = "xyes" ]; then
    run_cmd "systemctl enable puppet" "Failed to enable Puppet service"
    run_cmd "systemctl start puppet" "Failed to start Puppet service"
else
    run_cmd "systemctl disable puppet" "Failed to disable Puppet service"
    run_cmd "systemctl stop puppet" "Failed to stop Puppet service"
fi

if [ -z "$WAITFORCERT" ]; then
    WAITFORCERT=10
fi

EXTRA_ARGS="--waitforcert $WAITFORCERT"

print_status "Requesting certificate from Puppet master..."

CERT_SIGNED=no

while [ "$CERT_SIGNED" = "no" ]; do
    if [ "$DEBUG" = "yes" ]; then
        $PUPPETBIN agent --test $EXTRA_ARGS
    else
        $PUPPETBIN agent --test $EXTRA_ARGS > /dev/null 2>&1
    fi
    rc=$?
    if [ $rc -eq 0 ] || [ $rc -eq 2 ]; then
        CERT_SIGNED=yes
        print_status "Puppet agent execution has started."
    elif [ $rc -eq 1 ]; then
        print_status "Certificate request is pending. Waiting for it to be signed..."
        sleep 5
    else
        print_error "Puppet agent failed with exit code $rc"
        exit $rc
    fi
done

print_status "Puppet node setup completed successfully."
