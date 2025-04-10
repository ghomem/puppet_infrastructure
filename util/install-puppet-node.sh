#!/bin/bash

###############################################################################
# 1) FUNCTION DEFINITIONS
###############################################################################

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

function print_warning () {
    local message=$1
    echo -e "\033[1;33m$message\033[0m"
}

function run_cmd () {
    local cmd="$1"
    local err_message="$2"

    print_debug "Running: $cmd"
    if [ "$DEBUG" = "yes" ]; then
        eval $cmd
    else
        eval $cmd > /dev/null 2>&1
    fi

    handle_error $? "$err_message"
}

###############################################################################
# 2) PARSE ARGUMENTS
###############################################################################

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

# Default puppet master if not specified
if [ -z "$MASTER" ]; then
    MASTER="puppet.$DOMAIN"
fi

SETHOSTNAME=yes
START=no
NODECONF=/etc/puppetlabs/puppet/puppet.conf
PUPPETBIN=/opt/puppetlabs/bin/puppet
SWAPFILE=/swapfile

###############################################################################
# 3) SWAPFILE CREATION IF NEEDED
###############################################################################

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

###############################################################################
# 4) DISABLE CLOUD-INIT, SET MTU
###############################################################################

print_status "Disabling cloud-init and setting MTU to 1500..."

if [ -d "/etc/cloud" ]; then
    run_cmd "touch /etc/cloud/cloud-init.disabled" "Failed to disable cloud-init"
else
    print_warning "/etc/cloud does not exist. Skipping cloud-init disable."
fi

if [ -f "/etc/dhcp/dhclient.conf" ]; then
    echo "supersede interface-mtu 1500;" >> /etc/dhcp/dhclient.conf
    handle_error $? "Failed to set MTU in dhclient.conf"
else
    print_warning "/etc/dhcp/dhclient.conf does not exist. Skipping MTU override."
fi

###############################################################################
# 5) ENSURE PERL IS INSTALLED
###############################################################################

if ! command -v perl &> /dev/null; then
    print_status "Perl could not be found. Installing Perl..."
    if [ -f /etc/redhat-release ]; then
        # RHEL/CentOS
        run_cmd "yum install -y perl" "Failed to install Perl"
    else
        # Debian/Ubuntu
        run_cmd "apt-get update" "Failed to update apt-get"
        run_cmd "apt-get install -y perl" "Failed to install Perl"
    fi
else
    print_status "Perl is already installed."
fi

###############################################################################
# 6) FIX SUDOERS SECURE_PATH
###############################################################################

print_status "Backing up /etc/sudoers and fixing secure_path..."
run_cmd "cp -f /etc/sudoers /etc/sudoers.orig" "Failed to backup /etc/sudoers"
perl -pi -e 's/^(Defaults\s*secure_path\s?=\s?\"?[^\"\n]*)(\"?)$/$1:\/opt\/puppetlabs\/bin$2/' /etc/sudoers

###############################################################################
# 7) SET HOSTNAME (OPTIONAL)
###############################################################################

if [ "x$SETHOSTNAME" = "xyes" ]; then
    print_status "Setting hostname to $NODENAME..."
    run_cmd "hostnamectl set-hostname $NODENAME" "Failed to set hostname"
    grep "$NODENAME" /etc/hosts > /dev/null 2>&1 || echo "127.0.0.1 ${NODENAME}.${DOMAIN} ${NODENAME}" >> /etc/hosts
    handle_error $? "Failed to update /etc/hosts"
fi

###############################################################################
# 8) OS DETECTION AND INSTALL PUPPET 5 (TRUSTED=YES FOR UBUNTU)
###############################################################################

print_status "Detecting OS and installing Puppet agent..."

if [ -f /etc/redhat-release ]; then
    #
    # ------------------ RHEL/CENTOS LOGIC ------------------
    #
    RHELREPOPKGURL="https://yum.puppet.com/puppet-release-el-$(rpm -E '%{rhel}').noarch.rpm"
    RHELREPOPKG=/tmp/puppetlabs-release-puppet5.rpm

    run_cmd "yum install -y wget" "Failed to install wget"
    run_cmd "wget -O $RHELREPOPKG $RHELREPOPKGURL" "Failed to download Puppet repo package"
    run_cmd "yum install -y $RHELREPOPKG" "Failed to install Puppet repo package"
    run_cmd "yum install -y puppet-agent" "Failed to install Puppet agent"

else
    #
    # ------------------ DEBIAN/UBUNTU LOGIC ------------------
    #
    UBUNTUREPOPKGURL="http://apt.puppetlabs.com/puppet5-release-bionic.deb"
    UBUNTUREPOPKG="/tmp/puppetlabs-release-puppet5.deb"

    # Basic update/install
    run_cmd "apt-get update" "Failed to update apt-get"
    run_cmd "apt-get install -y wget" "Failed to install wget"

    # Download & install puppet5-release
    run_cmd "wget -O $UBUNTUREPOPKG $UBUNTUREPOPKGURL" "Failed to download Puppet repo package"
    run_cmd "dpkg -i $UBUNTUREPOPKG" "Failed to install Puppet repo package"

    # -------------------------------------------------------------------------
    # Because the Puppet 5 key is expired, we skip GPG validation entirely by
    # marking this repo "trusted=yes".
    # -------------------------------------------------------------------------
    run_cmd "rm -f /etc/apt/sources.list.d/puppet5.list /etc/apt/keyrings/puppet.gpg" \
            "Failed to remove any old puppet5 list or key"

    run_cmd "echo 'deb [trusted=yes] http://apt.puppetlabs.com bionic puppet5' \
> /etc/apt/sources.list.d/puppet5.list" \
            "Failed to create puppet5.list (trusted=yes)"

    # Now apt won't check any signature for the puppet5 repo
    run_cmd "apt-get update" "Failed to update apt-get after puppet5 repo added"

    run_cmd "apt-get install -t bionic -y puppet-agent" "Failed to install Puppet agent"
fi

###############################################################################
# 9) CONFIGURE PUPPET AGENT (puppet.conf) & START SERVICE
###############################################################################

print_status "Configuring Puppet agent..."
run_cmd "cp -f $NODECONF ${NODECONF}.orig" "Failed to backup puppet.conf"

cat > "$NODECONF" <<EOL
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
    run_cmd "systemctl start puppet"  "Failed to start Puppet service"
else
    run_cmd "systemctl disable puppet" "Failed to disable Puppet service"
    run_cmd "systemctl stop puppet"    "Failed to stop Puppet service"
fi

###############################################################################
# 10) CERTIFICATE REQUEST & FIRST RUN
###############################################################################

if [ -z "$WAITFORCERT" ]; then
    WAITFORCERT=10
fi

EXTRA_ARGS="--waitforcert $WAITFORCERT"

print_status "Requesting certificate from Puppet master..."

CERT_SIGNED=no
CERTFILE="/var/lib/puppet/ssl/certs/${NODENAME}.pem"

# Remove any existing SSL certificates for a fresh request
rm -rf /var/lib/puppet/ssl

while [ "$CERT_SIGNED" = "no" ]; do
    if [ "$DEBUG" = "yes" ]; then
        $PUPPETBIN agent --test $EXTRA_ARGS
    else
        $PUPPETBIN agent --test $EXTRA_ARGS > /dev/null 2>&1
    fi

    if [ -f "$CERTFILE" ]; then
        CERT_SIGNED=yes
        print_status "Certificate has been signed."
    else
        print_warning "Certificate request is pending. Waiting for it to be signed..."
        sleep 5
    fi
done

print_status "Running Puppet agent for the first time..."

if [ "$DEBUG" = "yes" ]; then
    $PUPPETBIN agent --test
else
    $PUPPETBIN agent --test > /dev/null 2>&1
fi

rc=$?
if [ $rc -eq 0 ] || [ $rc -eq 2 ] || [ $rc -eq 4 ] || [ $rc -eq 6 ]; then
    print_status "Puppet agent execution has completed."
else
    print_error "Puppet agent failed with exit code $rc. Try to run it manually with 'sudo puppet agent -t'"
    exit $rc
fi

print_status "Puppet node setup completed successfully."
