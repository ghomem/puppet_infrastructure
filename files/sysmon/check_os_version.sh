#/bin/sh

set -e

OS=`lsb_release -is`
VERSION=`lsb_release -rs`

STATE="OK - OS: ${OS} ${VERSION}"
status=0

echo $STATE
exit $status
