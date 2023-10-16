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
  echo "usage: cloudmin_import IMAGE_NAME SOURCE_TAR_ARCHIVE"
  exit $E_ERR
fi

IMAGE_NAME="${1}"
SOURCE_TAR_ARCHIVE="${2}"

# construct the DIR_NAME equal to the SOURCE_TAR_ARCHIVE without the .tar extension
DIR_NAME="${SOURCE_TAR_ARCHIVE%.tar}"

# we need to create the destination directory
mkdir -p $DIR_NAME

# we extract the tar to DIR_NAME and use --strip-components=1 to remove the root directory inside the archive
tar -xf $SOURCE_TAR_ARCHIVE -C $DIR_NAME --strip-components=1

# --source takes the full path
cloudmin restore-systems --host $IMAGE_NAME --source $DIR_NAME

rm -r $DIR_NAME
