#!/bin/sh

# Abort if one command fails
set -e

# Get the screenlocker timeout and grace time from command line
LOCK_TIMEOUT=$1
LOCK_GRACE=$2

# Find out user name and home directory
USERNAME=`whoami`
export HOME="/home/${USERNAME}"

# Check if the user is loged in
SYSLOG_TAG='linuxint-screenlocker'
who | awk '{print $1}' | grep -q "^$USERNAME\$" && {
  logger -p local1.notice -t $SYSLOG_TAG "User ${USERNAME} loged in, updating screenlock settings if needed"
} || {
  logger -p local1.notice -t $SYSLOG_TAG "User ${USERNAME} not loged in, skipping screenlock settings update"
  exit 0
}

# Check if we have to use k*config or k*config5 depending on the OS and set
# vars so the k*config* commands and qdbus work properly
MAJOR_RELEASE=`lsb_release -r | cut -f 2`
if [ "${MAJOR_RELEASE}" = "16.04" ]; then
	KWRITECONFIG='kwriteconfig'
        KREADCONFIG='kreadconfig'
	# set this var so qdbus works
	export DISPLAY=:0
else
	KWRITECONFIG='kwriteconfig5'
	KREADCONFIG='kreadconfig5'
	# Set this vars so qdbus works
	export UID=`id ${USERNAME} -u`
	export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${UID}/bus"
fi


# Take note if we must call the screenlocker config via dbus once we have adjusted the settings
MUST_CONFIG_SCREENLOCKER=false

# Check if the screen locker is actually enabled
CURRENT_AUTOLOCK_VALUE=`${KREADCONFIG} --file ${HOME}/.config/kscreenlockerrc --group Daemon --key Autolock`

# Enable the screen locker if needed
if [ "${CURRENT_AUTOLOCK_VALUE}" != 'true' ]; then
	${KWRITECONFIG} --file ${HOME}/.config/kscreenlockerrc --group Daemon --key Autolock 'true'
	MUST_CONFIG_SCREENLOCKER=true
fi

# Check if the screen locking on resume
# (e.g. when you close the laptop lid, you go for a coffee and you come back and open the lid again)
CURRENT_LOCK_ON_RESUME=`${KREADCONFIG} --file ${HOME}/.config/kscreenlockerrc --group Daemon --key LockOnResume`

# Enable the screen locker on resume if needed
if [ "${CURRENT_LOCK_ON_RESUME}" != 'true' ]; then
	${KWRITECONFIG} --file ${HOME}/.config/kscreenlockerrc --group Daemon --key LockOnResume 'true'
	MUST_CONFIG_SCREENLOCKER=true
fi

# Get the current lock time
CURRENT_LOCK_TIMEOUT=`${KREADCONFIG} --file ${HOME}/.config/kscreenlockerrc --group Daemon --key Timeout`

# Update the lock time if needed
if [ "${CURRENT_LOCK_TIMEOUT}" != "${LOCK_TIMEOUT}" ]; then
	${KWRITECONFIG} --file ${HOME}/.config/kscreenlockerrc --group Daemon --key Timeout ${LOCK_TIMEOUT}
	MUST_CONFIG_SCREENLOCKER=true
fi

# Get the current lock grace
CURRENT_LOCK_GRACE=`${KREADCONFIG} --file ${HOME}/.config/kscreenlockerrc --group Daemon --key LockGrace`

# Update the lock grace time if needed
if [ "${CURRENT_LOCK_GRACE}" != "${LOCK_GRACE}" ]; then
	${KWRITECONFIG} --file ${HOME}/.config/kscreenlockerrc --group Daemon --key LockGrace ${LOCK_GRACE}
	MUST_CONFIG_SCREENLOCKER=true
fi

# Configure the screenlocker via dbus if needed
if ${MUST_CONFIG_SCREENLOCKER}; then
	qdbus org.kde.screensaver /ScreenSaver configure
fi
