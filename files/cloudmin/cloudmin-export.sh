#!/bin/bash

# error code
E_ERR=1

# validate sudo
if [ "$EUID" -ne 0 ]
  then echo -e "This script needs to be run as root.\nExiting..."
  exit $E_ERR
fi

# exit if we don't have exactly 2 arguments and echo a friendly message
if [[ -z $2 || -n $3 ]]; then
  echo "usage: cloudmin_export IMAGE_NAME DESTINATION_DIRECTORY"
  exit $E_ERR
fi

# random suffix for temp_dir, so that it has a unique name
SUFFIX="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 6 | head -n 1)"
# timestamp suffix for the identification the tar archive and the main folder
# inside the tar archive
TIMESTAMP=`date +%Y-%b-%d-%Hh%Mm`

IMAGE_NAME="${1}"
NAME_WITH_TIMESTAMP="${IMAGE_NAME}-${TIMESTAMP}"
DESTINATION_DIRECTORY="${2}"
DIR_WITH_SUFFIX="temp_dir_${SUFFIX}"

# create a temporary directory inside the DESTINATION_DIRECTORY
mkdir -p $DESTINATION_DIRECTORY/$DIR_WITH_SUFFIX/$NAME_WITH_TIMESTAMP
echo "Created temp_dir!"

# we make the backup of the image with the destination being the temp directory
cloudmin backup-systems --host $IMAGE_NAME --dest $DESTINATION_DIRECTORY/$DIR_WITH_SUFFIX/$NAME_WITH_TIMESTAMP

# tar the files, keeping the main folder that has the same name as the image
tar cf $DESTINATION_DIRECTORY/$NAME_WITH_TIMESTAMP.tar --directory=$DESTINATION_DIRECTORY/$DIR_WITH_SUFFIX $NAME_WITH_TIMESTAMP
echo "tar done!"

#remove the temporary folder
rm -r $DESTINATION_DIRECTORY/$DIR_WITH_SUFFIX
echo "Removed temp_dir!"
