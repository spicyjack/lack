# $Id: gen_sign_disk_key.sh,v 1.12 2008-11-08 06:02:47 brian Exp $
# Copyright (c)2008 Brian Manning
# elspicyjack (at) gmail dot com
# Get support and more info about this script at:
# http://groups.google.com/group/project-naranja

# script to take a subset of keys in a directory and make them into keys used
# to unlock a disk key
# - choose one of the generated GPG keys and make that the master account
# - choose another 'X' number of keys and make them secondary accounts
# - take all of the master and secondary accounts and move them to $OUTDIR/keys
# - take the secondary keys and import them into the master account's public
# key
# - generate the disk key
# - sign the disk key with the public keys of the master and secondary
# accounts
# - wrap the keylist file using a specified master/secondary account key
# - optionally wrap the challenge file
# - copy the keys to the proper directories on the flash disk 

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
SCRIPTNAME=$(basename $0)

# some defaults
QUIET=1 # most quiet
# don't write a key ID/passprhase challenge file by default
CHALLENGE=0
# path to write keys to; change with: --output
KEY_OUT_DIR="/home/brian/keys"
# number of keys to copy over
COUNT=20

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

function temp_key_move () {
	# move the generated keys from the temp directory to the --output directory

    # exit if there's no keylist file (empty directory?)
    if [ ! -e $OUTDIR/keylist.txt ]; then return; fi
    if [ ! -d $KEY_OUT_DIR/keys ]; then
        mkdir -p $KEY_OUT_DIR/keys
    fi # if [ ! -d $KEY_OUT_DIR/$OUTPUT_SUB_DIR ]
    find $OUTDIR \( -name "*.pub" -o -name "*.sec" \) \
        -exec $MV '{}' $KEY_OUT_DIR/keys \;
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

function copy_keys () {
	# rename the keystore files to the name of their key ID
   
    if [ $QUIET -gt 0 ]; then
		echo "Moving ${KEY_ID}.[sec|pub]"
	fi
	$MV $KEYDIR/$KEY_ID.sec $KEYDIR/$KEY_ID.pub $OUTDIR
    cmd_status "(secret/public key) mv" $?
} # rename_keys

function get_master_key () {
    echo $KEYLIST | fmt
    echo "Please choose the GPG key that will become the master disk key:"
    #echo -n "(input will not echo) ->"
    #stty -echo
    read ANSWER
    echo
    #stty echo
    if [ -f $INPUT_DIR/$ANSWER.sec ]; then
        echo "Using key '0x$ANSWER' as the master key"
        MASTER_KEY=$ANSWER
        cp $INPUT_DIR/$MASTER_KEY.sec $OUTPUT_DIR/secring.gpg
        cp $INPUT_DIR/$MASTER_KEY.pub $OUTPUT_DIR/pubring.gpg
        return
        # recurse over public keys here
    else 
        echo "ERROR: key '0x$ANSWER' does not exist;"
        echo
        get_master_key
    fi
} # function get_master_key

function show_examples () {
    cat <<-EOE
    # script examples
    sh ${SCRIPTNAME} --input /dev/shm/output \ 
        --output /dev/shm/test --verbose --gpgid 1234ABCD --challenge
EOE

    exit 0
} # show_examples


function show_help () {
    cat <<-EOF 

    ${SCRIPTNAME} [options] 

    SCRIPT OPTIONS
    -h|--help      Show this help output
    -e|--examples  Show script example usage
    -c|--count     Number of keys to copy over to the output directory
    -i|--input     Directory to read keys from
    -o|--output    Directory to write keys and protected keylist to
    -g|--gpgid     GNU PrivacyGuard key ID to encrypt the keylist file with
    -t|--tempdir   Temporary directory to use when signing files with GPG
    -x|--challenge Copy from the challenge.txt file as applicable
    -q|--quiet     Don't output anything (unless there's an error)
    -v|--verbose   Very noisy output

EOF
    exit 0
} # show_help

### BEGIN SCRIPT ###

# run getopt
TEMP=$(${GETOPT} -o hec:i:o:g:t:xqv \
--long help,examples,count:,input:,output:,gpgid:,tempdir: \
--long challenge,quiet,verbose \
-n "${SCRIPTNAME}" -- "$@")

cmd_status $GETOPT $?

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
        -e|--examples|--example) # show the script options
            show_examples
            ;;
        -c|--count) # count
            COUNT=$2
            shift 2
            ERRORLOOP=$(($ERRORLOOP - 1))
            ;; # --count
        -i|--input) # input key directory
            INPUT_DIR=$2
            shift 2
            ERRORLOOP=$(($ERRORLOOP - 1))
            ;; # --input
        -o|--output) # output key directory
            OUTPUT_DIR=$2
            shift 2
			ERRORLOOP=$(($ERRORLOOP - 1))
            ;; # --outut
        -g|--gpgid) # GNU PG ID to use to sign the keylist with
            GPG_ID=$2
            shift 2
			ERRORLOOP=$(($ERRORLOOP - 1))
            ;; # --gpgid
        -t|--tempdir) # temporary directory to use for the gpg funny business
            TEMPDIR=$2
            shift 2
            ERRORLOOP=$(($ERRORLOOP - 1))
            ;; # --tempdir
        -x|--challenge) # copy the contents of the challenge file
            CHALLENGE=1;
            ERRORLOOP=$(($ERRORLOOP - 1))
            shift
            ;; # --challenge
        -q|--quiet) # don't output anything (unless there's an error)
            QUIET=0;
            ERRORLOOP=$(($ERRORLOOP - 1))
            shift
            ;; # --quiet
        -v|--verbose) # output pretty messages
            QUIET=2
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

if [ $QUIET -gt 0 ]; then echo "- Writing keys to ${OUTPUT_DIR}"; fi

# script to help sort keys
if [ ! -d $OUTPUT_DIR ]; then
    mkdir -p $OUTPUT_DIR
    if [ $? -gt 0 ]; then
        echo "ERROR: could not create directory $OUTPUT_DIR"
        exit 1
    fi # if [ $? ­ne 0 ]
fi # if [ ! -d $OUTPUT_DIR ]

# grab the list of keys from the input directory
GREP_KEY_COUNT=$(($COUNT * 2))
#if [ $QUIET -gt 0 ]; then echo "- copying $KEYCOUNT keys to $OUTPUT_DIR"; fi
echo "- copying $COUNT keys to $OUTPUT_DIR";

# create a list of keys to be copied; the first or last $KEYCOUNT keys created
# in $INPUT_DIR
KEYLIST=$(/bin/ls -t -1 $INPUT_DIR 2>/dev/null | grep "[0-9A-Z]*\.[ps]" \
    | head -n $GREP_KEY_COUNT | sed '{s/\.pub$//; s/\.sec$//;}' | uniq | sort )
KEYSFOUND=$(echo $KEYLIST| wc -w )
if [ $KEYSFOUND -ge $GREP_KEY_COUNT ]; then
    echo "ERROR: not enough keys found to continue; found $KEYSFOUND keys"
    echo "in input directory '$INPUT_DIR'"
    exit 1
fi
# this sets $MASTER_KEY
get_master_key

for KEY in $(echo $KEYLIST); 
do
    if [ $QUIET -gt 0 ]; then echo "  - moving key $KEY"; fi
    mv $INPUT_DIR/$KEY.sec $INPUT_DIR/$KEY.pub $OUTPUT_DIR
    grep $KEY $INPUT_DIR/keylist.txt >> $OUTPUT_DIR/keylist.txt
    if [ $CHALLENGE -gt 0 ]; then
        grep $KEY $INPUT_DIR/challenge.txt >> $OUTPUT_DIR/challenge.txt
    fi
done

# take the secondary keys and import them into the master account's public key
IMPORT_CMD="gpg --no-default-keyring --homedir $OUTPUT_DIR"
IMPORT_CMD="$IMPORT_CMD --always-trust --lock-never --import"
for KEY in $(echo $KEYLIST); 
do
    IMPORT_CMD="$IMPORT_CMD ${OUTPUT_DIR}/${KEY}.pub"
done

# run the import key command
if [ $QUIET -gt 0 ]; then 
    echo "- Importing public keys (master key: 0x$MASTER_KEY)"; 
fi
eval ${IMPORT_CMD}
cmd_status "Importing public keys" $?

# generate the disk key, then sign the disk key with the public keys of the
# master and secondary accounts
if [ $QUIET -gt 0 ]; then 
    echo "- Creating disk key (master key: 0x$MASTER_KEY)"; 
fi
DISK_KEY_CMD="head -c 2925 /dev/random | uuencode -m - "
DISK_KEY_CMD="$DISK_KEY_CMD | head -n 66 | tail -n 65 "
DISK_KEY_CMD="$DISK_KEY_CMD | gpg --no-default-keyring"
DISK_KEY_CMD="$DISK_KEY_CMD --homedir $OUTPUT_DIR --armor --encrypt"
DISK_KEY_CMD="$DISK_KEY_CMD --recipient 0x${MASTER_KEY}"
DISK_KEY_CMD="$DISK_KEY_CMD --always-trust --lock-never "
for KEY in $(echo $KEYLIST); 
do
    DISK_KEY_CMD="$DISK_KEY_CMD --recipient 0x${KEY}"
done
DISK_KEY_CMD="$DISK_KEY_CMD > $OUTPUT_DIR/disk_key-${MASTER_KEY}.key"

# run it
eval ${DISK_KEY_CMD}
cmd_status "Creating the encrypted disk key" $?

# wrap the keylist file using a specified account key
if [ "x${GPG_ID}" != "x" ]; then
    if [ $QUIET -gt 0 ]; then 
        echo "- Wrapping keylist file (GPG Key ID: 0x${GPG_ID})"; 
    fi
    WRAP_KEY_CMD="gpg --armor --encrypt --recipient 0x${GPG_ID} "
    WRAP_KEY_CMD="$WRAP_KEY_CMD $OUTPUT_DIR/keylist.txt"
    eval ${WRAP_KEY_CMD}
    cmd_status "Wrapping keylist file with GPG key 0x${GPG_ID}" $?

    if [ $QUIET -gt 0 ]; then echo "- Deleting keylist.txt file"; fi
    rm $OUTPUT_DIR/keylist.txt
    cmd_status "Deleting keylist.txt file" $?
fi

# optionally wrap the challenge file

if [ $CHALLENGE -gt 0 ]; then
    if [ $QUIET -gt 0 ]; then 
        echo "- Wrapping challenge file (GPG Key ID: 0x${GPG_ID})"; 
    fi
    WRAP_KEY_CMD="gpg --armor --encrypt --recipient 0x${GPG_ID} "
    WRAP_KEY_CMD="$WRAP_KEY_CMD $OUTPUT_DIR/challenge.txt"
    eval ${WRAP_KEY_CMD}
    cmd_status "Wrapping challenge.txt file with GPG key 0x${GPG_ID}" $?

    if [ $QUIET -gt 0 ]; then echo "- Deleting challenge.txt file"; fi
    rm $OUTPUT_DIR/challenge.txt
    cmd_status "Deleting challenge.txt file" $?

fi

# copy the keys to the proper directories on the flash disk 


