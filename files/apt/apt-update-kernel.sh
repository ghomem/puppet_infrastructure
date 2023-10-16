#!/bin/bash

echo "currently running               linux-`uname -r`"
LATEST=`cat /boot/grub/menu.lst |grep ^kernel |head -n 1 | cut -d ' ' -f 1`
echo "current default $LATEST"

apt-get update 2>&1 > /dev/null
RC=$?

if [ ! $RC -eq 0 ]; then
  echo "error running apt-get update"
  exit $RC
fi

# this detects if the linux image is generic or aws (or others)
my_image=`uname -r | sed 's/[0-9\.\-]*/linux-image-/'`

# this is to avoid an interactive debian dialogue regarding what to do on menu.lst
# the result is that it won't be added the latest entry
DEBIAN_FRONTEND='noninteractive' apt-get install -y $my_image >&  /dev/null
RC=$?

# if we failed here let's bail out
if [ ! $RC -eq 0 ]; then
  echo "error running apt-get install"
  exit $RC
fi

# we force menu.lst to be updated with the latest kernel entry
mv -f  /boot/grub/menu.lst /boot/grub/menu.lst.old
/usr/sbin/update-grub-legacy-ec2 -y >&  /dev/null
RC=$?

LATEST=`cat /boot/grub/menu.lst |grep ^kernel |head -n 1 | cut -d ' ' -f 1`
echo "postrun default $LATEST"

exit $RC
