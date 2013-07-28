#!/bin/sh
# !DESC-EN!50!networking!Set up host networking and view network status

# format of the description line:
# !token and language!script name!script description
# note that the keyword 'DESC' is grepped for, so it must be exact

# $Id: networking.sh,v 1.1 2009-07-23 08:30:56 brian Exp $
# Copyright (c)2009 by Brian Manning (elspicyjack at gmail dot com)
# PLEASE DO NOT E-MAIL THE AUTHOR ABOUT THIS SOFTWARE
# The proper venue for questions is the Propaganda mailing list at:
# http://groups.google.com/group/psas or <psas@groups.google.com>
#
# display the networking information

### MAIN SCRIPT ###
# what's my name?
SCRIPTNAME=$(basename $0)
# exit status
EXIT=0
# path to dialog
DIALOG="/usr/bin/dialog"
# where to write dialog output to
DIALOG_OUT="/tmp/dialog.out"
# default networking
NETWORKING="dhcp"
# DHCP pid
UDHCPC_PID="/var/run/udhcpc.eth0.pid"

# zeroconf IP address info
IP_ADDR="0.0.0.0"
NETMASK="255.255.255.255"
GATEWAY="0.0.0.0"
DNS_SERVER="0.0.0.0"
SEARCH_DOMAIN="example.com"

### FUNCTIONS ###
networking_static() {
# set up static networking, verify what the user entered is valid
dialog \
        --backtitle "Propaganda: Configure static networking" \
        --form "Use the up/down cursor keys to move between fields, \
the right/left cursor keys to edit a field, the HOME/END keys \
to go to the beginning/end of a field, or the <TAB> key to move \
to move to the bottom of the dialog.\n\nAny changes in this dialog \
will prompt you to restart networking; if you're currently connected \
via the network, restarting the network will end your session.\n" \
        20 70 0 \
        "IP address" 1 1 "$IP_ADDRESS" 1 18 32 0 \
        "Netmask" 2 1 "$NETMASK" 2 18 32 100 \
        "Gateway" 3 1 "$GATEWAY" 3 18 32 0 \
        "DNS server" 4 1 "$DNS_SERVER" 4 18 32 0 \
        "Search Domain" 5 1 "$SEARCH_DOMAIN" 5 18 32 0 \
2>$DIALOG_OUT
    NEW_IP_ADDR=$(cat $DIALOG_OUT | head -n 1 | tr -d '\n')
    NEW_NETMASK=$(cat $DIALOG_OUT | head -n 2 | tail -n 1 | tr -d '\n')
    NEW_GATEWAY=$(cat $DIALOG_OUT | head -n 3 | tail -n 1 | tr -d '\n')
    NEW_DNS_SERVER=$(cat $DIALOG_OUT | head -n 4 | tail -n 1 | tr -d '\n')
    NEW_SEARCH_DOMAIN=$(cat $DIALOG_OUT | head -n 5 | tail -n 1 | tr -d '\n')
    RESTART_SIAB=0
    if [ "x$NEW_IP_ADDR" != "x$IP_ADDR" ]; then RESTART_SIAB=1; fi
    if [ "x$NEW_NETMASK" != "x$NETMASK" ]; then RESTART_SIAB=1; fi
    if [ "x$NEW_GATEWAY" != "x$GATEWAY" ]; then RESTART_SIAB=1; fi
    if [ "x$NEW_DNS_SERVER" != "x$DNS_SERVER" ]; then RESTART_SIAB=1; fi
    if [ "x$NEW_SEARCH_DOMAIN" != "x$SEARCH_DOMAIN" ]; then RESTART_SIAB=1; fi
    if [ $RESTART_SIAB -eq 1 ]; then
        $DIALOG --backtitle "Propaganda: Confirm Networking Restart" \
    --yesno "Networking configuration has changed.\n\
Restart networking?" \
        6 50 2>$DIALOG_OUT
        RESTART_STATUS=$?
        if [ $RESTART_STATUS -eq 0 ]; then
            $DIALOG --infobox "Configuring static IP address..." 3 50
            if [ -e $UDHCPC_PID ]; then
                /bin/kill -TERM $(cat ${UDHCPC_PID})
                /bin/rm $UDHCPC_PID
            fi
            /sbin/ifconfig eth0 $NEW_IP_ADDR netmask $NEW_NETMASK \
                gateway $NEW_GATEWAY up
            echo "search $NEW_SEARCH_DOMAIN" > /etc/resolv.conf
            echo "nameserver $NEW_DNS_SERVER" >> /etc/resolv.conf

        fi # if [ $RESTART_STATUS -eq 0 ];
    fi # if [ $RESTART_SIAB -eq 1 ];
} # networking_static ()

networking_dhcp () {
    $DIALOG --infobox "Configuring IP address via DHCP..." 3 50
    /bin/ip link set eth0 up
    /sbin/udhcpc -i eth0 -p $UDHCPC_PID
} # networking_dhcp ()

parse_dialog () {
    ACTION=$(cat /tmp/dialog.exit | tr -d '\n')
    case "$ACTION" in
        "Static") networking_static;;
        "DHCP") networking_dhcp;;
        "Zeroconf") # use the Zeroconf protocol to obtain an IP address
            ;;
        "Main Menu") # return to the main menu
            exit 0
            ;;
    esac
    # re-launch this script so it's status updates
    exec /bin/sh /etc/menuitems/networking.sh 
}
### SCRIPT SETUP ###
TEMP=$(/usr/bin/getopt -o hvo: \
    --long help,verbose,option: -n '${SCRIPTNAME}' -- "$@")

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
    -o|--option     Random option
    NOTE: Long switches do not work with BSD systems (GNU extension)

EOF
		exit 0;;		
		-q|--quiet)	# don't output anything (unless there's an error)
						QUIET=1
						shift;;
        -v|--verbose) # output pretty messages
                        QUIET=0
                        shift;;
        -o|--option) # a long option with an argument
                        OPTION=$2; 
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

if [ -e $UDHCPC_PID ]; then
    SYS_MSG=$(echo "udhcpc running as PID ")
    SYS_MSG=$(echo ${SYS_MSG}; cat ${UDHCPC_PID}; echo "\n\n")
fi
SYS_MSG=$(echo "${SYS_MSG}"; echo "Current IP configuration:\n"; ip address)

### SCRIPT MAIN LOOP ###
dialog --backtitle "Propaganda: Networking" \
    --title "Networking Setup" \
    --begin 2 2 \
    --menu "$SYS_MSG" 21 70 3 \
    "Main Menu" "Return to the main menu" \
    "DHCP" "Grab a DHCP lease" \
    "Static" "Configure static networking" \
2> /tmp/dialog.exit

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
