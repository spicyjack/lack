#!/bin/sh
# $Id: streaming.sh,v 1.4 2009-07-24 08:39:27 brian Exp $
# Copyright (c)2009 by Brian Manning (elspicyjack at gmail dot com)
# PLEASE DO NOT E-MAIL THE AUTHOR ABOUT THIS SOFTWARE
# The proper venue for questions is the Propaganda mailing list at:
# http://groups.google.com/group/psas or <psas@groups.google.com>
#
# start mpg123 using the URL provided; start it in a while loop so if it dies,
# it can get restarted after a configurable delay

### MAIN SCRIPT ###
# what's my name?
SCRIPTNAME=$(/usr/bin/basename $0)
# exit status
EXIT=0
# delay between restarts of mpg123
RESTART_DELAY=3
# our stream URL
STREAM_URL="http://localhost:8000/propaganda"
# PID of mpg123
MPG123_PID="/var/run/mpg123.pid"
# mpg123 logfile
MPG123_LOG="/var/log/mpg123.log"
# our PID
STREAMING_SH_PID="/var/run/streaming.sh.pid"
# flag to know whether or not we should be running
STREAMING_FLAG="/var/run/streaming.flag"
# don't use wget by default
USE_WGET=1
# set quiet mode by default, needs to be set prior to the getops call
QUIET=1

### SCRIPT FUNCTIONS ###
clear_pid_files () {
    # remove any leftover PID files
    if [ -e $MPG123_PID ]; then /bin/rm $MPG123_PID; fi
    if [ -e $STREAMING_SH_PID ]; then /bin/rm $STREAMING_SH_PID; fi
    if [ -e $STREAMING_FLAG ]; then /bin/rm $STREAMING_FLAG; fi
} # clear_pid_files ()

### SCRIPT SETUP ###
TEMP=$(/usr/bin/getopt -o hvd:ksu:w \
    --long help,verbose,delay:,killall,spdif-out,url:,use-wget \
    -n '${SCRIPTNAME}' -- "$@")

# if getopts exited with an error code, then exit the script
#if [ $? -ne 0 -o $# -eq 0 ] ; then
if [ $? != 0 ] ; then 
	echo "Run '${SCRIPTNAME} --help' to see script options" >&2 
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
		cat <<-EOF

	${SCRIPTNAME} [options]

    SCRIPT OPTIONS
    -h|--help       Displays this help message
    -v|--verbose    Nice pretty output messages
    -d|--delay      Number of seconds between restarts of mpg123
    -k|--killall    Kill all running instances of this script, don't start
    -s|--use-spdif  Use the S/PDIF digital audio out, if found
    -u|--url        URL to connect to for streaming
    -w|--no-wget    Don't use wget | mpg123 for streaming (less reliable)

EOF
		exit 0;;		
        -v|--verbose) # output pretty messages
                        QUIET=0
                        shift;;
        -d|--delay) # delay between runs of mpg123
                        MPG123_DELAY=$2; 
                        ERRORLOOP=$(($ERRORLOOP - 1));
                        shift 2;;
        -k|--killall) # kill all instances of this process
                        KILLALL=1
                        shift;;
        -s|--use-spdif) # kill all instances of this process
                        USE_SPDIF=1
                        shift;;
        -u|--url) # URL to connect to for streaming
                        STREAM_URL=$2; 
                        ERRORLOOP=$(($ERRORLOOP - 1));
                        shift 2;;
        -w|--no-wget) # URL to connect to for streaming
                        USE_WGET=0
                        shift;;
		--) shift; break;;
	esac
    # exit if we loop across getopts too many times
    ERRORLOOP=$(($ERRORLOOP + 1))
    if [ $ERRORLOOP -gt 4 ]; then
        echo "ERROR: too many getopts passes;"
        echo "Maybe you have a getopt option with no branch?"
        echo "Last option parsed was: ${1}"
        exit 1
    fi # if [ $ERROR_LOOP -gt 3 ];

done

# kill all copies of this script?
if [ "x$KILLALL" != "x" ]; then
    # touch the flag file; this prevents the while loop below from restarting
    # mpg123 after we kill it
    touch $STREAMING_FLAG
    # now check to see if there's a PID file for MPG123; if so, kill that
    # process; this will cause this script to exit and clean up after itself
    if [ -e $MPG123_PID ]; then
        if [ $VERBOSE -gt 0 ]; then echo "Killing mpg123 process"; fi
        kill -TERM $(cat $MPG123_PID)
        clear_pid_files
        exit 0
    fi
    exit 1
fi

# verify another copy of mpg123 is not running already
if [ -e $MPG123_PID ]; then
    exit 1
fi

# no, another copy is not running, start a copy
# verify that a 'no streaming' flag is not set
while [ ! -e $STREAMING_FLAG ]; do
    echo $$ > $STREAMING_SH_PID
    # background mpg123, then keep checking for the PID in the output of PS;
    if [ $USE_WGET -eq 1 ]; then
        # tested in psasp; the command on the right side of the pipe gets
        # written to $!, which is what we want
        # wget needs to be shut up however 
        /usr/bin/wget -q -O - $STREAM_URL \
            | /usr/bin/mpg123 -o alsa - >> $MPG123_LOG 2>&1 &
    else
        # straight mpg123; the icecast metadata should go to the logfile
        /usr/bin/mpg123 -o alsa $STREAM_URL >> $MPG123_LOG 2>&1 &
    fi
    # wget -q -O - - http://stream:7767/vault | mpg123 --stdout - | aplay -D
    # plughw:0,2 -f cd
    # - view output devices: aplay -l
    # capture the MPG123 pid
    echo $! > $MPG123_PID
    # verify the PID file exists before doing this next bit
    while [ -e $MPG123_PID ]; do
        PIDCHECK=$(/bin/cat $MPG123_PID)
        PSCHECK=$(/bin/ps | grep -c $PIDCHECK)
        if [ $PSCHECK -eq 0 ]; then
            RESTART_DATE=$(date | tr -d '\n')
            echo "mpg123 PID $MPG123_PID exited..." >> $MPG123_LOG
            echo "Restarting mpg123 at $RESTART_DATE" >> $MPG123_LOG
            /bin/rm $MPG123_PID
            break
        fi
        sleep $RESTART_DELAY
    done # while [ -e $MPG123_PID ]; do
done # while [ ! -e /tmp/mpg123.run ];

clear_pid_files

exit ${EXIT}

### BEGIN LICENCE
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; version 2 dated June, 1991.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program;  if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111, USA.
### END LICENSE

# vi: set ft=sh sw=4 ts=4:
# eof
