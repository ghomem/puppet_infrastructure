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
START=yes
NODECONF=/etc/puppetlabs/puppet/puppet.conf
PUPPETBIN=/opt/puppetlabs/bin/puppet

###############################################################################
# ENSURE PERL IS INSTALLED
###############################################################################

if ! command -v perl &> /dev/null; then
    print_status "Perl could not be found. Installing Perl..."
    run_cmd "apt-get update" "Failed to update apt-get"
    run_cmd "apt-get install -y perl" "Failed to install Perl"
else
    print_status "Perl is already installed."
fi

###############################################################################
#  FIX SUDOERS SECURE_PATH
###############################################################################

print_status "Backing up /etc/sudoers and fixing secure_path..."
run_cmd "cp -f /etc/sudoers /etc/sudoers.orig" "Failed to backup /etc/sudoers"
perl -pi -e 's/^(Defaults\s*secure_path\s?=\s?\"?[^\"\n]*)(\"?)$/$1:\/opt\/puppetlabs\/bin$2/' /etc/sudoers

###############################################################################
# SET HOSTNAME
###############################################################################

if [ "x$SETHOSTNAME" = "xyes" ]; then
    print_status "Setting hostname to $NODENAME..."
    run_cmd "hostnamectl set-hostname $NODENAME" "Failed to set hostname"
    grep "$NODENAME" /etc/hosts > /dev/null 2>&1 || echo "127.0.0.1 ${NODENAME}.${DOMAIN} ${NODENAME}" >> /etc/hosts
    handle_error $? "Failed to update /etc/hosts"
fi

###############################################################################
# OS DETECTION AND INSTALL PUPPET 5 (TRUSTED=YES FOR UBUNTU)
###############################################################################

print_status "Detecting OS and installing Puppet agent..."

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

PUPPET_AGENT_VERSION="5.5.22-1bionic"
run_cmd "apt-mark unhold puppet-agent 2>/dev/null || true" "Failed to unhold Puppet agent package"
run_cmd "apt-get install -y --allow-downgrades puppet-agent=${PUPPET_AGENT_VERSION}" "Failed to install Puppet agent"
run_cmd "apt-mark hold puppet-agent" "Failed to hold Puppet agent package"
run_cmd "test -x $PUPPETBIN" "Expected Puppet binary not found at $PUPPETBIN"

###############################################################################
# CONFIGURE PUPPET AGENT (puppet.conf) & START SERVICE
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

print_status "Ensuring Puppet service is stopped during certificate bootstrap..."
run_cmd "systemctl stop puppet 2>/dev/null || true" "Failed to stop Puppet service"
run_cmd "systemctl disable puppet 2>/dev/null || true" "Failed to disable Puppet service"

###############################################################################
# CERTIFICATE REQUEST & FIRST RUN
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

if [ "x$START" = "xyes" ]; then
    print_status "Enabling and starting Puppet service..."
    run_cmd "systemctl enable puppet" "Failed to enable Puppet service"
    run_cmd "systemctl start puppet"  "Failed to start Puppet service"
else
    print_status "Leaving Puppet service disabled."
    run_cmd "systemctl disable puppet" "Failed to disable Puppet service"
    run_cmd "systemctl stop puppet 2>/dev/null || true" "Failed to stop Puppet service"
fi

print_status "Puppet node setup completed successfully."
