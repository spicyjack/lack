#!/bin/bash
# rsync's antlinux to/from remote computers

# TODO
# - add a switch to redirect output of rsync to a file
# - add a loopback mount checker, goes thru all the loopback devices and sees
# 	if that specific device is in use or not

SCRIPTNAME=$(basename $0)
# files rsync should not be monkeying with
# NOTE: anything in a /dev directory should be excluded, as the boot floppies
# are using devfs, which creates the devices in /dev automatically
EXCLUDES="--exclude=rsync.sh --exclude=loop.sh --exclude=make_initrd.sh"
EXCLUDES=" $EXCLUDES --exclude=2.4.x/*/*"

TEMP=$(/usr/bin/getopt -o dhnbvt:f: \
    --long delete,dry-run,verbose,bwlimit,to:,from: \
    -n '$SCRIPTNAME' -- "$@")

# if there's no options passed in, then exit with error 1
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
# read in the $TEMP variable
eval set -- "$TEMP"

while true ; do
	case "$1" in
		-h) 
		echo "$SCRIPTNAME:"
        echo " [-t -f -n -d -b] (to, from, dry-run, delete, bwlimit)"; 
		exit 1;;
		-v|--verbose)	DEBUG=1; shift;;
		-n|--dry-run) 	# turns on dry run
						RSYNC_OPTS="$RSYNC_OPTS -n "; shift;;
		-d|--delete)	# turns on delete; note, delete will delete files on
						# the destination that don't exist on the source
						RSYNC_OPTS="$RSYNC_OPTS --delete "; shift;;
		-b|--bwlimit) 	# set a bandwidth limit of 20k/sec
						RSYNC_OPTS="$RSYNC_OPTS --bwlimit=20 "; shift;;
		-t|--to) 		# copy to a host
			XFERPATH="/usr/local/src/antlinux/ $2:/usr/local/src/antlinux/"; 
			shift 2;;
		-f|--from)		# copy from a host 
			XFERPATH="$2:/usr/local/src/antlinux/ /usr/local/src/antlinux/"; 
			shift 2;;
		--) shift; break;;
	esac
done

if [ -n "$XFERPATH" ]; then 
	if [ $DEBUG ]; then
		echo -n "running \"/usr/bin/rsync -avessh"
		echo $RSYNC_OPTS $EXCLUDES $XFERPATH"\""
		echo
	fi # if [ $DEBUG ]; then
	/usr/bin/rsync -azvessh $EXCLUDES $RSYNC_OPTS $XFERPATH 
fi # if [ -n "$XFERPATH" ]; then
