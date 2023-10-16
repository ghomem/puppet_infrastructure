#!/bin/bash

# NOTE:
#
# This is a wrapper to apt-get install made to be used with other commands.
# Therefore apt-get update must be run before executing this command

RC_ERR=1

function check_installed ()
{

  PKGNAME=$1
  dpkg -s $PKGNAME 2>1 >/dev/null
  return $?
  
}

function check_update ()
{

  PKGNAME=$1
  aptitude -F%p --disable-columns search ~U |grep -x $PKGNAME 2>1 > /dev/null
  return $?

}

if [ -z $1 ]; then
  echo "usage: `basename $0` PKGNAMENAME"
  exit $RC_ERR
fi

export DEBIAN_FRONTEND=noninteractive
APT_OPTS="-y -o DPkg::Options::=--force-confdef -o DPkg::Options::=--force-confold"

PKGNAME=$1

check_installed $PKGNAME
RC=$?

if [ ! $RC -eq 0 ]; then
  echo "package $PKGNAME not installed"
  exit $RC_ERR
fi

check_update $PKGNAME
RC=$?

if [ ! $RC -eq 0 ]; then
  VERSION=`dpkg -s $PKGNAME |grep "^Version:" |cut -d ' ' -f 2`
  echo "package $PKGNAME $VERSION has no update available (or was already updated)"
  exit $RC_ERR
fi

#echo "package $PKGNAME will be updated"
apt-get install $APT_OPTS $PKGNAME 2>&1 > /dev/null
RC=$?

if [ ! $RC -eq 0 ]; then
  echo "apt-get returned an error while updating package $PKGNAME"
else
  VERSION=`dpkg -s $PKGNAME |grep "^Version:" |cut -d ' ' -f 2`
  echo "package $PKGNAME updated to version $VERSION"
fi

exit $RC
