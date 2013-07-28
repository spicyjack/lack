#!/bin/sh
# !DESC-EN!00!icecast!Start/stop Icecast, view current status 
# !CFG!start_on_boot!yes!Starts the icecast server on system startup
# !CFG!listen_port!8000!Icecast listen port
# !CFG!admin_username!admin!Icecast admin username
# !CFG!admin_pass!NULL!Icecast admin password
# !CFG!stream_username!stream!Icecast stream username
# !CFG!stream_pass!NULL!Icecast stream password
# !CFG!pidfile!/var/run/icecast.pid!Icecast Process ID file

# format of the description line:
# !DESC-language!script name!script description
# note that the keyword 'DESC' is grepped for, so it must be exact
# format of the configuration variable line(s):
# !CFG-language!config_var!default_value!config variable description
# note that the keyword 'CFG' is grepped for, so it must be exact

# $Id: icecast.sh,v 1.1 2009-07-23 08:30:56 brian Exp $
# Copyright (c)2009 by Brian Manning (elspicyjack at gmail dot com)
# PLEASE DO NOT E-MAIL THE AUTHOR ABOUT THIS SOFTWARE
# The proper venue for questions is the Propaganda mailing list at:
# http://groups.google.com/group/psas or <psas@groups.google.com>
#
# shell script that collects stats from an Icecast server and presents them to
# the user

### MAIN SCRIPT ###
# what's my name?
SCRIPTNAME=$(basename $0)
# URL for checking icecast status
ICE_URL="http://localhost:8000/simple.xsl"
# PIDfile
# FIXME pull this from the config file(s)
ICE_PIDFILE="/var/run/icecast2/icecast.pid"
# exit status
EXIT=0

# set quiet mode by default, needs to be set prior to the getops call
QUIET=1

### SCRIPT SETUP ###
TEMP=$(/usr/bin/getopt -o hvu: \
    --long help,verbose,url: -n '${SCRIPTNAME}' -- "$@")

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
    -u|--url        URL to query for Icecast status
    NOTE: Long switches do not work with BSD systems (GNU extension)

EOF
		exit 0;;		
		-q|--quiet)	# don't output anything (unless there's an error)
						QUIET=1
						shift;;
        -v|--verbose) # output pretty messages
                        QUIET=0
                        shift;;
        -u|--url) # url for the status page
                        ICE_URL=$2; 
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

if [ ! -e $ICE_PIDFILE ]; then
    ICE_MSG="Icecast is currently not running"
else
    ICE_PID=$(cat $ICE_PIDFILE)
    ICE_MSG="Icecast PID: ${ICE_PID}\nIcecast status from ${ICE_URL}: \n \
    ${ICE_STATUS} \n"  
fi # if [ ! -e $ICE_PIDFILE ]; then

### SCRIPT MAIN LOOP ###
ICE_STATUS=$(/usr/bin/wget -q -O - ${ICE_URL} | grep -v "^<")
dialog --backtitle "Propaganda: Icecast" \
--title "Icecast Status" --begin 2 2 --msgbox "$ICE_MSG\n$ICE_STATUS" \
    21 75 2> /tmp/dialog.exit
#echo "$SCRIPTNAME exit code was: ${?}"
#sleep 1
exit $?

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
