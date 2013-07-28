#!/bin/sh

# $Id: gnupg-batch.sh,v 1.23 2009-03-20 09:10:37 brian Exp $
# Copyright (c)2006 Brian Manning
# elspicyjack (at) gmail dot com
# Get support and more info about this script at:
# http://groups.google.com/group/project-naranja

# script to generate GNUPG keys automagically using the batch function built
# into gpg.  Requires the 'diceparse.pl' script, sold separately.

# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307 USA

# external programs used
GPG=$(which gpg)
TRUE=$(which true)
GETOPT=$(which getopt)
MV=$(which mv)
CAT=$(which cat)
RM=$(which rm)
UNAME=$(which uname)
SCRIPTNAME=$(basename $0)

# some defaults
QUIET=1 # most quiet
# don't write a key ID/passprhase challenge file by default
CHALLENGE=0
# path to write keys to; change with: --output
KEY_OUT_DIR="/home/brian/keys"
# path to diceparse.pl; change with: --dicepath
DICEPATH="/home/brian/src/perl-hg/"
# generate a diceware phrase consisting of this many words (rolls); 
# change with: --dicesize
DICESIZE="5"
# path to word list; change with: --wordlist
WORDLIST="/home/brian/diceware.en.txt"
# generate this many gpg keys; 
# change with: --count, default = 0 (generate keys until infinity,
# or until you run out of hard drive space)
KEY_COUNT=0
# temporary directory used for storing generated keys; use this parameter to
# cut down on disk writes (flogging the hard drive); the down side is that you
# lose the keys should the system crash or something happen
# change with: --tempdir, default is unset, don't use a temp dir
#KEY_TEMP_DIR=
# create this many keys in the temporary directory before moving them to the
# directory listed in --output
# change with: --tempnum, default = 1000
KEY_TEMP_NUM="1000"

# helper functions
function cmd_status () {
    # check the status of the last run command; run a shell if it's anything
    # but 0
    COMMAND=$1
    STATUS=$2
    if [ $STATUS -ne 0 ]; then
        echo "Command '${COMMAND}' failed with status code: ${STATUS}"
        exit 1 
    fi
} # cmd_status

function get_dice_passphrase () {
    local KEY_SIZE=$1
    PASSPHRASE=$(perl ${DICEPATH}/diceparse.pl -r ${KEY_SIZE} -l ${WORDLIST})
    cmd_status "diceparse.pl" $?
} # get_dice_passphrase

function temp_key_move () {
	# move the generated keys from the temp directory to the --output directory

    # exit if there's no keylist file (empty directory?)
    if [ ! -e $OUTDIR/keylist.txt ]; then return; fi
    # get a new passphrase for the subdirectory name
    get_dice_passphrase 3
    OUTPUT_SUB_DIR=$(echo ${PASSPHRASE} | sed 's/[^0-9a-zA-Z]//g')
    if [ ! -d $KEY_OUT_DIR/$OUTPUT_SUB_DIR ]; then
        mkdir -p $KEY_OUT_DIR/$OUTPUT_SUB_DIR
    fi # if [ ! -d $KEY_OUT_DIR/$OUTPUT_SUB_DIR ]
    find $OUTDIR \( -name "*.pub" -o -name "*.sec" \) \
        -exec $MV '{}' $KEY_OUT_DIR/$OUTPUT_SUB_DIR \;
    cmd_status "(key files) find -exec mv" $?
    cat $OUTDIR/keylist.txt \
        | sort -k 6 > $KEY_OUT_DIR/$OUTPUT_SUB_DIR/keylist.txt
    cmd_status "(keylist) cat/sort" $?
    # delete the old keylist file
    rm $OUTDIR/keylist.txt
    if [ -e $OUTDIR/keylist.txt ]; then exit 1; fi

    # now do the same for the challenge file if --challenge was set
    if [ $CHALLENGE -gt 0 ]; then
        cat $OUTDIR/challenge.txt \
            | sort -k 6 > $KEY_OUT_DIR/$OUTPUT_SUB_DIR/challenge.txt
        cmd_status "(challenge) cat/sort" $?
        # delete the old challenge file
        rm $OUTDIR/challenge.txt
        if [ -e $OUTDIR/challenge.txt ]; then exit 1; fi
    fi # if [ $CHALLENGE -gt 0 ]

} # temp_key_move

function rename_keys () {
	# rename the keystore files to the name of their key ID
    if [ $QUIET -gt 0 ]; then
		echo "Renaming keystore.[sec|pub] to ${KEY_ID}.[sec|pub]"
	fi
	$MV $OUTDIR/keystore.sec $OUTDIR/$KEY_ID.sec
    cmd_status "(secret key) mv" $?
    $MV $OUTDIR/keystore.pub $OUTDIR/$KEY_ID.pub
    cmd_status "(public key) mv" $?
} # rename_keys

function show_help () {
    cat <<-EOF 

    ${SCRIPTNAME} [options] 

    SCRIPT OPTIONS
    -h|--help      Show this help output
    -l|--list      Diceware wordlist to use
    -s|--dicesize  Size of password to generate using diceparse.pl (Default: 5)
    -p|--dicepath  Path to the 'diceparse.pl' script
    -o|--output    Directory to write keys and keylist to
    --overwrite    Overwrite duplicate keys; multiple entries will exist in
                   the keylist file
    -c|--count     Create this many keys only
    -t|--tempdir   Write 'X' number of keys to this directory, then move the 
                   keys to a new directory in the output directory (saves on
                   disk writes; tempdir should be a tmpfs filesystem like
                   /dev/shm in Linux)
    -n|--tempnum   The 'X' number of keys to write to a temporary directory
                   Default is 1000 keys
    -x|--challenge Generate a Key ID/passphrase "challenge" file
    -q|--quiet     Don't output anything (unless there's an error)
    -v|--verbose   Very noisy output

EOF
    exit 0
} # show_help

function show_examples () {
    cat <<-EOE
    # script examples
    sh ${SCRIPTNAME} -w diceware.en.txt
    sh ${SCRIPTNAME} --dicepath . --verbose --tempdir /dev/shm \
        --tempnum 2 --count 10

EOE

} # show_examples

### BEGIN SCRIPT ###
# BSD's getopt is simpler than the GNU getopt; we need to detect it 
OSDETECT=$($UNAME -s)
if [ $OSDETECT == "Darwin" ]; then
    # this is the BSD part
    echo "WARNING: BSD OS Detected; long switches will not work here..."
    TEMP=$(${GETOPT} hec:l:n:o:p:qt:vw:x $*)
    cmd_status $GETOPT $?
elif [ $OSDETECT == "Linux" ]; then
    # and this is the GNU part
    TEMP=$(${GETOPT} -o hec:l:n:o:p:qt:vw:x \
        --long help,examples,count:,dicepath:,list:,output:,overwrite \
        --long quiet,tempdir:,tempnum:,verbose,wordlist:,challenge \
        -n "${SCRIPTNAME}" -- "$@")
    cmd_status $GETOPT $?
else
    echo "Error: Unknown OS Type.  I don't know how to call"
    echo "'getopts' correctly for this operating system.  Exiting..."
    exit 1
fi

# Note the quotes around `$TEMP': they are essential!
# read in the $TEMP variable
eval set -- "$TEMP"

# read in command line options and set appropriate environment variables
# if you change the below switches to something else, make sure you change the
# getopts call(s) above
ERRORLOOP=1
while true ; do
    case "$1" in
        -h|--help) # show the script options
            show_help
            ;;
        -e|--examples) # show the script options
            show_examples
            ;;
        -l|--list|-w|--wordlist) # wordlist file to use
            WORDLIST=$2
            shift 2
            ERRORLOOP=$(($ERRORLOOP - 1))
            ;; # --list
        -p|--dicepath) # path to the diceparse.pl script
            DICEPATH=$2
            shift 2
			ERRORLOOP=$(($ERRORLOOP - 1))
            ;; # --dicepath
        -s|--dicesize) # size of the password to generate using diceparse.pl
            DICESIZE=$2
            shift 2
			ERRORLOOP=$(($ERRORLOOP - 1))
            ;; # --dicepath
        -o|--output) # final output directory for keys and keylist files
            KEY_OUT_DIR=$2
            shift 2
			ERRORLOOP=$(($ERRORLOOP - 1))
            ;; # --output
        -c|--count) # how many keys to generate
            KEY_COUNT=$2
            shift 2
			ERRORLOOP=$(($ERRORLOOP - 1))
            ;; # --count
        -t|--tempdir) # temporary directory for generating keys
            KEY_TEMP_DIR=$2
            shift 2
			ERRORLOOP=$(($ERRORLOOP - 1))
            ;; # --tempdir
        -n|--tempnum) # number of keys to generate before moving them all to
			# directory specified in --output (KEY_OUT_DIR)
            KEY_TEMP_NUM=$2
            shift 2
			ERRORLOOP=$(($ERRORLOOP - 1))
            ;; # --tempnum
        --overwrite) # overwrite existing keys (script exits if not set)
            OVERWRITE_KEYS=1
			ERRORLOOP=$(($ERRORLOOP - 1))
            shift
            ;; # --overwrite        
        -q|--quiet) # don't output anything (unless there's an error)
            QUIET=0;
            # set --noprompt
            PROMPT=0;
            ERRORLOOP=$(($ERRORLOOP - 1))
            shift
            ;; # --quiet
        -v|--verbose) # output pretty messages
            QUIET=2
			ERRORLOOP=$(($ERRORLOOP - 1))
            shift
            ;; # --verbose
        -x|--challenge) # output pretty messages
            CHALLENGE=1
			ERRORLOOP=$(($ERRORLOOP - 1))
            shift
            ;; # --verbose
        --) shift; break
            ;; # --
    esac
    # exit if we loop across getopts too many times
    ERRORLOOP=$(($ERRORLOOP + 1))
    if [ $ERRORLOOP -gt 4 ]; then
        echo "ERROR: too many getopt passes;" >&2
        echo "Maybe you have a getopt option with no branch?" >&2
        exit 1
    fi # if [ $ERROR_LOOP -gt 3 ];
    
done

# tell the keys where to go
if [ $KEY_TEMP_DIR ]; then
	OUTDIR=$KEY_TEMP_DIR
else 
	OUTDIR=$KEY_OUT_DIR
fi

if [ $QUIET -gt 0 ]; then echo "- Writing keys to '${OUTDIR}'"; fi

# script to help sort keys
if [ ! -d $OUTDIR ]; then
    if [ $QUIET -gt 0 ]; then echo "- Creating directory '${OUTDIR}'"; fi
    mkdir -p $OUTDIR
    RETVAL=$?
    if [ $RETVAL -gt 0 ]; then
        echo "ERROR: could not create directory '$OUTDIR'"
        exit 1
    fi # if [ $? ­ne 0 ]
fi # if [ ! -d $OUTDIR ]

# escape forward slashes for the later sed call
SED_OUTDIR=$(echo $OUTDIR | sed 's/\//\\\//g')
if [ $QUIET -gt 1 ]; then echo "- sedded output directory ${SED_OUTDIR}"; fi

# some counters
KEY_COUNTER=0
# run gnupg multiple times generating keys
while $TRUE; do 
    # generate a shorter challenge passphrase
    # a second file will be created that lists challenge words and key ID's
    get_dice_passphrase 3
    CHALLENGE_PASSPHRASE=$PASSPHRASE

    # grab a GPG key password from diceparse; sets $PASSPHRASE
    get_dice_passphrase 5 

    # make a new file from the template
    cat batch.gnupg.template | sed "s/#PASSPHRASE#/${PASSPHRASE}/" \
        | sed "s/#OUTDIR#/${SED_OUTDIR}/g" > batch.gnupg

    # now generate the key
    time $GPG --batch --gen-key batch.gnupg
    cmd_status $GPG $?

    # grab it's ID so you can rename it
    KEY_ID=$(${GPG} --no-default-keyring  --list-secret-keys \
        --secret-keyring ${OUTDIR}/keystore.sec \
        --keyring ${OUTDIR}/keystore.pub | \
        head -n 3 | tail -n 1 | \
        sed -e 's/sec   1024D\///' -e 's/ .*$//' )
        #sed '{s/sec   1024D\///; s/ .*$//}' )
	if [ $QUIET -gt 1 ]; then echo "key ID is: ${KEY_ID}"; fi	
    # rename them
    if [ ! -e $OUTDIR/$KEY_ID.sec -a ! -e $OUTDIR/$KEY_ID.pub ]; then
		rename_keys
    else 
		if [ $OVERWRITE ]; then
			if [ $QUIET -gt 0 ]; then
				echo "WARNING: duplicate key ${KEY_ID} was just overwritten"
			fi
			rename_keys
		else 
	        echo "ERROR: key ${KEY_ID} exists! Will not overwrite key!"
   			exit 1
		fi # if [ $OVERWRITE ];
    fi # if [ ! -e $OUTDIR/$KEY_ID.sec -a ! -e $OUTDIR/$KEY_ID.pub ];
    NOW=$(date | tr -d '\n')
    if [ $CHALLENGE -gt 0 ]; then
        echo "${NOW} ${CHALLENGE_PASSPHRASE} ${KEY_ID}" >> $OUTDIR/challenge.txt
    fi # if [ $CHALLENGE -gt 0 ]
    echo "${NOW} ${KEY_ID} ${PASSPHRASE}" >> $OUTDIR/keylist.txt
    if [ $QUIET -gt 0 ]; then echo "added ${KEY_ID} to keylist.txt"; fi
	# increment the counter
	KEY_COUNTER=$(($KEY_COUNTER + 1))
	# see if we've hit the temp counter
	MODULUS=$(($KEY_COUNTER % $KEY_TEMP_NUM))
	if [ $QUIET -gt 1 ]; then echo "- modulus was $MODULUS"; fi
	#if [ "$KEY_TEMP_DIR" -a $MODULUS -eq 0 ]; then
	if [ $MODULUS -eq 0 ]; then
		if [ $KEY_TEMP_DIR ]; then
			temp_key_move
		fi # if [ -n $KEY_TEMP_DIR ];
	fi # if [ -n $KEY_TEMP_DIR -a $MODULUS -eq 0 ];
	if [ $KEY_COUNTER -eq $KEY_COUNT ]; then
		if [ $KEY_TEMP_DIR ]; then
			temp_key_move
		fi # if [ -n $KEY_TEMP_DIR ];
		break
	fi # if [ $KEY_COUNTER -eq $KEY_COUNT ];
done
# vi: set sw=4 ts=4: 
# end of line
