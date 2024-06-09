#!/bin/sh

set -e

# Check if lsb_release command is available
if command -v lsb_release >/dev/null 2>&1; then
    OS=$(lsb_release -is)
    VERSION=$(lsb_release -rs)
# Check if /etc/os-release file exists
elif [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VERSION=$VERSION_ID
else
    echo "UNKNOWN - OS information not found"
    exit 3
fi

STATE="OK - OS: ${OS} ${VERSION}"
status=0

echo $STATE
exit $status
