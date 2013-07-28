#!/bin/sh
# !DESC-EN!70!shellinabox!Start/stop/configure shellinabox

# format of the description line:
# !token and language!script name!script description
# note that the keyword 'DESC' is grepped for, so it must be exact

# FIXME other things to add here as menu setup options
# - logging? (--verbose, redirect output to a file and use the tail dialog?)
# - favicon file??
# - beep wav??
# run shellinabox as a non-root user?

# $Id: shellinabox.sh,v 1.1 2009-07-23 08:30:56 brian Exp $
# Copyright (c)2009 by Brian Manning (elspicyjack at gmail dot com)
# PLEASE DO NOT E-MAIL THE AUTHOR ABOUT THIS SOFTWARE
# The proper venue for questions is the Propaganda mailing list at:
# http://groups.google.com/group/psas or <psas@groups.google.com>

# show the status of shellinabox; allow configuration and starting/stopping of
# the program

### MAIN SCRIPT ###
# what's my name?
SCRIPTNAME=$(basename $0)
# exit status
EXIT=0
# path to dialog
DIALOG="/usr/bin/dialog"
# where to write dialog output to
DIALOG_OUT="/tmp/dialog.out"
# skip the main menu dialog (set with --configure)
SKIP_MAIN=0
# PID file
SIAB_PID="/var/run/shellinabox.pid"
# logfile
SIAB_LOG="disabled"
# listen port
SIAB_PORT=4200
# SSL Certificate
SSL_CERT="/etc/ssl/certs/certificate.pem"
# cascading stylesheet file that gets handed out to clients
SIAB_CSS="/etc/styles.css"

# set quiet mode by default, needs to be set prior to the getops call
QUIET=1

### FUNCTIONS ###
start_siab () {
    # warn the user
    $DIALOG --infobox "Starting shellinabox..." 3 50
    # start shellinaboxd
    /usr/bin/shellinaboxd --cert=/etc/ssl/certs \
    --background=$SIAB_PID --port=$SIAB_PORT \
    --static-file=styles.css:$SIAB_CSS
    # sleep to give the dialogs a chance to capture the correct info
    sleep 2
} # start_siab () 

stop_siab () {
    # warn the user
    $DIALOG --infobox "Stopping shellinabox..." 3 50
    # kill the process
    kill -TERM $(cat $SIAB_PID)
    /bin/rm $SIAB_PID
} # stop_siab ()

configure_siab () {
    # configures shellinabox via a dialog form
    $DIALOG \
        --backtitle "Propaganda: Configure shellinabox" \
        --form "Use the keyboard cursor keys or the <TAB> key to move \
around in the dialog.  Any changes in this dialog will prompt you \
to restart shellinabox\n" \
        20 60 0 \
        "Listen port" 1 1 "$SIAB_PORT" 1 22 32 0 \
        "SSL Certificate File" 2 1 "$SSL_CERT" 2 22 32 100 \
        "Logfile" 3 1 "$SIAB_LOG" 3 22 32 0 \
        "CSS file" 4 1 "$SIAB_CSS" 4 22 32 0 \
        2>$DIALOG_OUT
    NEW_SIAB_PORT=$(cat $DIALOG_OUT | head -n 1 | tr -d '\n')
    NEW_SSL_CERT=$(cat $DIALOG_OUT | head -n 2 | tail -n 1 | tr -d '\n')
    NEW_SIAB_LOG=$(cat $DIALOG_OUT | head -n 3 | tail -n 1 | tr -d '\n')
    NEW_SIAB_CSS=$(cat $DIALOG_OUT | head -n 4 | tail -n 1 | tr -d '\n')
    RESTART_SIAB=0
    if [ "x$NEW_SIAB_PORT" != "x$SIAB_PORT" ]; then RESTART_SIAB=1; fi
    if [ "x$NEW_SSL_CERT" != "x$SSL_CERT" ]; then RESTART_SIAB=1; fi
    if [ "x$NEW_SIAB_LOG" != "x$SIAB_LOG" ]; then RESTART_SIAB=1; fi
    if [ "x$NEW_SIAB_CSS" != "x$SIAB_CSS" ]; then RESTART_SIAB=1; fi
    if [ $RESTART_SIAB -eq 1 ]; then
        $DIALOG --backtitle "Propaganda: Confirm Shellinabox Restart" \
    --yesno "Shellinabox configuration has changed.\n\
Restart shellinabox?" \
        6 50 2>$DIALOG_OUT
        RESTART_STATUS=$?
        if [ $RESTART_STATUS -eq 0 ]; then
            SIAB_PORT=$NEW_SIAB_PORT
            SSL_CERT=$NEW_SSL_CERT
            SIAB_LOG=$NEW_SIAB_LOG
            SIAB_CSS=$NEW_SIAB_CSS
            # these need to call up to the functions above
            stop_siab
            start_siab
        fi # if [ $RESTART_STATUS -eq 0 ];
    fi # if [ $RESTART_SIAB -eq 1 ];
}

parse_dialog () {
    ACTION=$(cat $DIALOG_OUT | tr -d '\n')
    case "$ACTION" in
        "Start") start_siab ;;
        "Stop") stop_siab ;;
        "Configure") configure_siab ;;
        "Main Menu") exit 0 ;;
    esac

    # re-launch this script so it's status updates
    exec /bin/sh /etc/menuitems/shellinabox.sh
} # parse_dialog () 

### SCRIPT SETUP ###
TEMP=$(/usr/bin/getopt -o hvcl:p:s: \
    --long help,verbose,configure,logfile:,port:,sslcert: \
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
    -c|--configure  Go straight to the Configure menu
    -l|--logfile    Path to logfile; default is no logging
    -p|--port       Listen port, default is port 4200/TCP
    -s|--sslcert    Absolute path to SSL cert file (certificate.pem)
EOF
		exit 0;;		
		-q|--quiet)	# don't output anything (unless there's an error)
						QUIET=1
						shift;;
        -v|--verbose) # output pretty messages
                        QUIET=0
                        shift;;
        -c|--configure) # go straight to the configure menu
                        CONFIGURE=1
                        SKIP_MAIN=1
                        shift;;
        -l|--logging) # log shellinabox output
                        SIAB_LOG=$2; 
                        ERRORLOOP=$(($ERRORLOOP - 1));
                        shift 2;;
        -p|--port) # listen port for shellinabox
                        SIAB_PORT=$2; 
                        ERRORLOOP=$(($ERRORLOOP - 1));
                        shift 2;;
        -s|--sslcert) # SSL certificate file
                        SSL_CERT=$2; 
                        ERRORLOOP=$(($ERRORLOOP - 1));
                        shift 2;;
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

# skip the main shellinabox menu
if [ $SKIP_MAIN -eq 1 ]; then
    # configure shellinabox
    if [ $CONFIGURE -eq 1 ]; then configure_siab; fi 
fi # if [ $SKIP_MAIN -eq 1 ]; then

# get the current status of shellinabox
if [ -e $SIAB_PID ]; then
    SIAB_STATUS="Running, PID is $(cat $SIAB_PID)"
    START_TIME="shellinabox started: $(stat -c '%y' $SIAB_PID)\n"
    SIAB_ACTION="Stop"
    SIAB_DESC="Stop the current shellinabox process"
else
    SIAB_STATUS="Not running"
    START_TIME="\n"
    SIAB_ACTION="Start"
    SIAB_DESC="Start shellinabox, listen on port TCP/$SIAB_PORT"
fi

### SCRIPT MAIN LOOP ###
$DIALOG --nocancel \
--backtitle "Propaganda: Shellinabox" \
--title "Shellinabox Options/Configuration" \
--menu "Current shellinabox status: $SIAB_STATUS\n\
Shellinabox is set to listen on TCP port: $SIAB_PORT" 12 70 3 \
"Main Menu" "Return to the main menu" \
"$SIAB_ACTION" "$SIAB_DESC" \
"Configure" "Configure shellinabox" \
2> $DIALOG_OUT

# parse_dialog will either call itself again, or exit to the main menu
parse_dialog

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
# end of line
