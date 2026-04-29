#!/bin/bash

set -euo pipefail

metapkg=$(dpkg -l 'linux-image-*' | awk '/^ii/ && $2 !~ /[0-9]\.[0-9]/ {print $2}')

if [[ -z "$metapkg" ]]; then
    echo "No kernel metapackage found." >&2
    exit 1
fi

apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y --only-upgrade "$metapkg"
