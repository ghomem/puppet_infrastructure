#!/bin/bash

# Pushes differences from files changed on a deployment user repo
# as if they came from your account; useful for node declarations

# NOTE: the git repository must be cloned from its https:// url

set -e # Exit immediately if a command exits with a non-zero status.

E_ERR=1

function print_usage () {

  echo "usage: commush.sh FULL_NAME EMAIL [BRANCH]"
  exit $E_ERR

}

NAME=$1
MAIL=$2

if [ -z $MAIL ]; then
    print_usage
fi

if [ -z $3 ]; then
	BRANCH='master'
else
	BRANCH=$3
fi

# protect against accidental misuse of branches
MYBRANCH=`git rev-parse --abbrev-ref HEAD`

if ! [ $MYBRANCH == $BRANCH ]; then
	echo "error: your current branch is $MYBRANCH but you are trying to commush to $BRANCH"
fi

echo "** When prompted for the password you must insert your authentication token **"
echo

git config --global user.name  "$NAME"
git config --global user.email "$MAIL"

echo 'Type your commit message'
read -e MESSAGE

# Abort unless we have user confirmation
echo '=== git status --untracked-files=no ==='
git status --untracked-files=no
echo 'Are you sure you want to commush these changes in the files above [Y/n]?'
read -e user_confirmation
if [[ ! $user_confirmation =~ ^([Yy](es)?)?$ ]]
then
    exit 0
fi

# commit all changes and push
git commit -a -m "$MESSAGE"
git push origin $BRANCH
