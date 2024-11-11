#!/bin/bash
# usage example: sudo ./install-puppet-node.sh [--debug] NODENAME DOMAIN [MASTER] [WAITFORCERT]

DEBUG=0

# Process options
while [ $# -gt 0 ]; do
    case "$1" in
        --debug)
            DEBUG=1
            ;;
        --)
            shift
            break
            ;;
            *)
                # Non-option argument
                break
                ;;
    esac
    shift
done

if [ $# -lt 2 ]; then
    echo "Usage: $0 [--debug] NODENAME DOMAIN [MASTER] [WAITFORCERT]"
    exit 1
fi

# Define logging functions with color
function log_info {
    echo -e "\033[1;32m$@\033[0m"
}

function log_warn {
    echo -e "\033[1;33m$@\033[0m"
}

function log_error {
    echo -e "\033[1;31m$@\033[0m"
}

# Function to run commands with optional debug output
run_cmd() {
    if [ "$DEBUG" -eq 1 ]; then
        "$@"
    else
        "$@" >/dev/null 2>&1
    fi
}

SWAPFILE=/swapfile

log_info "Checking if swap is already in use..."
if [ -z "$(swapon --show)" ]; then
    if grep -q 'container' /proc/1/environ; then
        log_info "No swap detected. Creating swap file at $SWAPFILE..."
        # Create and configure swap file
        run_cmd /bin/dd if=/dev/zero of=$SWAPFILE bs=1M count=1024
        run_cmd /sbin/mkswap $SWAPFILE
        run_cmd chmod 600 $SWAPFILE
        run_cmd /sbin/swapon $SWAPFILE
        run_cmd cp -f /etc/fstab /etc/fstab.orig
        grep $SWAPFILE /etc/fstab || echo "$SWAPFILE  swap  swap  defaults  0  0" >>/etc/fstab
    else
        log_info "Swap is not in use, but the system is not a container. Skipping swap creation."
    fi
else
    log_info "Swap is already in use."
fi

log_info "Disabling cloud-init and setting MTU to 1500..."
run_cmd touch /etc/cloud/cloud-init.disabled
echo "supersede interface-mtu 1500;" >>/etc/dhcp/dhclient.conf

log_info "Checking if Perl is installed..."
if ! command -v perl &>/dev/null; then
    log_info "Perl is not installed. Installing Perl..."
    if [ -f /etc/redhat-release ]; then
        # For RHEL/CentOS
        run_cmd yum install -y perl
    else
        # For Debian/Ubuntu
        run_cmd apt-get update
        run_cmd apt-get install -y perl
    fi
else
    log_info "Perl is already installed."
fi

log_info "Modifying /etc/sudoers to fix sudo path..."
run_cmd cp -f /etc/sudoers /etc/sudoers.orig
run_cmd perl -pi -e 's#^(Defaults\s*secure_path\s?=\s?"?[^"\n]*)(?"?)$#$1:/opt/puppetlabs/bin$2#' /etc/sudoers

SETHOSTNAME=yes
START=no
NODENAME=$1
DOMAIN=$2
MASTER=${3:-puppet.$DOMAIN}
WAITFORCERT=${4:-10}
NODECONF=/etc/puppetlabs/puppet/puppet.conf
PUPPETBIN=/opt/puppetlabs/bin/puppet

if [ "x$SETHOSTNAME" = "xyes" ]; then
    log_info "Setting hostname to $NODENAME..."
    run_cmd hostnamectl set-hostname $NODENAME
    grep -q "$NODENAME" /etc/hosts || echo "127.0.0.1 ${NODENAME}.${DOMAIN} ${NODENAME}" >>/etc/hosts
fi

log_info "Detecting operating system..."
if [ -f /etc/redhat-release ]; then
    log_info "Detected RHEL/CentOS. Installing Puppet agent..."
    RHELREPOPKGURL="https://yum.puppet.com/puppet-release-el-$(rpm -E '%{rhel}').noarch.rpm"
    RHELREPOPKG=/tmp/puppetlabs-release-puppet5.rpm
    run_cmd yum install -y wget
    run_cmd wget -O $RHELREPOPKG $RHELREPOPKGURL
    run_cmd yum install -y $RHELREPOPKG
    run_cmd yum install -y puppet-agent
else
    log_info "Detected Ubuntu/Debian. Installing Puppet agent..."
    UBUNTUREPOPKGURL=http://apt.puppetlabs.com/puppet5-release-bionic.deb
    UBUNTUREPOPKG=/tmp/puppetlabs-release-puppet5.deb
    run_cmd apt-get update
    run_cmd apt-get install -y wget
    run_cmd wget -O $UBUNTUREPOPKG $UBUNTUREPOPKGURL
    run_cmd dpkg -i $UBUNTUREPOPKG
    run_cmd apt-get update
    run_cmd apt-get install -y puppet-agent
fi

log_info "Configuring Puppet agent..."
run_cmd cp -f $NODECONF ${NODECONF}.orig
cat <<EOF >/etc/puppetlabs/puppet/puppet.conf
[main]
server=${MASTER}
node_name=cert
certname=${NODENAME}
logdir=/var/log/puppet
vardir=/var/lib/puppet
ssldir=/var/lib/puppet/ssl
rundir=/var/run/puppet
factpath=\$vardir/lib/facter
EOF

log_info "Ensuring Puppet service is running..."
run_cmd $PUPPETBIN resource service puppet ensure=running enable=true provider=systemd

if [ "x$START" = "xyes" ]; then
    log_info "Enabling and starting Puppet service..."
    run_cmd systemctl enable puppet
    run_cmd systemctl start puppet
else
    log_info "Disabling and stopping Puppet service..."
    run_cmd systemctl disable puppet
    run_cmd systemctl stop puppet
fi

log_info "Running Puppet agent to generate certificate request..."

while true; do
    if $PUPPETBIN agent --test --waitforcert 0 >/tmp/puppet_agent_output 2>&1; then
        log_info "Puppet agent ran successfully."
        break
    else
        if grep -q "Could not request certificate" /tmp/puppet_agent_output; then
            log_error "Error requesting certificate. Check network connectivity and Puppet server availability."
            exit 1
        elif grep -q "no certificate found and waitforcert is disabled" /tmp/puppet_agent_output; then
            log_warn "Certificate request submitted. Waiting for certificate to be signed on Puppet server..."
            sleep 5
        elif grep -q "Exiting; no certificate found and waitforcert is disabled" /tmp/puppet_agent_output; then
            log_warn "Certificate request pending. Waiting for certificate to be signed on Puppet server..."
            sleep 5
        else
            log_warn "Puppet agent ran successfully."
	    break
	fi
    fi
done

log_info "Puppet agent setup completed successfully."
