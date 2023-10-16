#!/bin/bash

# Usage examples:
#
# /usr/local/AS/bin/rdiff.sh /home/backups/snapshots/puppet.customer.com
# /usr/local/AS/bin/rdiff.sh /home/backups/snapshots/puppet.customer.com INTERACTIVE

# command line arguments
BASEDIR="$1"

# Global vars and functions

E_OK=0
E_ERR=1
INTERACTIVE=0
BEGIN_SEPARATOR="--------------------"
END_SEPARATOR_L="/-------------------"
END_SEPARATOR_R="-------------------/"
DIFF_OPTS=

# counts the nr of arguments to provide the list length

list_length () {
         echo $#;
}

handle_error () {

    echo usage: `basename $0` SNAPSHOTSDIR [INTERACTIVE]
    exit $E_ERR

}

compare_dirs () {

MYDIR_A=$1
MYDIR_B=$2

    # remove the annoying " and " so we can copy/paste for file diffs
    diff $DIFF_OPTS -qr $MYDIR_A $MYDIR_B | sed 's/ and .\// .\//'

}

#### MAIN ####


if [ -z $BASEDIR ]; then
    handle_error
fi

if [ ! -d $BASEDIR ]; then
    handle_error
fi

# any other argument triggers interactive mode
if [ ! -d $2 ]; then
    INTERACTIVE=1
fi

# list of directories to compare
# note: we cd first to avoid train long names

cd $BASEDIR
LIST=`find . -maxdepth 1 -mindepth 1 -type d | sort -V`

# we produce two other lists
# * A one the misses the last element
# * B one that misses the first element
#
# and we compare the A[j] with B[j]

j=0
A=
B=
LEN=`list_length $LIST`
LIM=$(( $LEN -1 ))

for d in $LIST; do
    if [ ! $j -eq 0 ]; then
        B="$B $d"
    fi
    if [ ! $j -eq $LIM ]; then
        A="$A $d"
    fi
    j=$(( $j + 1 ))
done

LIM=$(( $LIM -1 ))
ARR_A=($A)
ARR_B=($B)

if [ ! $INTERACTIVE -eq 0 ]; then
    clear
fi

echo
echo "Differences report for directories inside $BASEDIR:"
echo

for j in `seq 0 $LIM`; do
    DIR_B=${ARR_B[j]}
    DIR_A=${ARR_A[j]}
    echo
    echo "$BEGIN_SEPARATOR `basename $DIR_B` -> `basename $DIR_A` $BEGIN_SEPARATOR"
    echo
    compare_dirs $DIR_B $DIR_A
    echo
    echo "$END_SEPARATOR_L `basename $DIR_B` -> `basename $DIR_A` $END_SEPARATOR_R"
    j=$(( $j + 1 ))
    echo
    if [ ! $INTERACTIVE -eq 0 ]; then
        echo "press ENTER for next difference"
        read
    fi
done

if [ ! $INTERACTIVE -eq 0 ]; then
    echo "Done!"
fi

exit $E_OK
