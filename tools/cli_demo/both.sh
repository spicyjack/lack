#!/bin/sh

# script to demo whiptail and dialog
# $Id: both.sh,v 1.1 2006-12-31 10:18:21 brian Exp $
# Copyright (c)2006 by Brian Manning (elspicyjack at gmail dot com)

# get some program locations first
DIALOG=$(which dialog)
WHIPTAIL=$(which whiptail)


# some script defaults
BACKTITLE="This is both.sh, a dialog/whiptail tester..."
TITLE="Please answer this question:"
TEXTMESSAGE="Hopefully, this example message should span across several lines, so that the viewer can get an idea of how well the line wrapping works with this program.  If the line wrapping sucks ass, then you'll know which program not to use in your scripts"

$WHIPTAIL --title "${TITLE}" --backtitle "${BACKTITLE}" \
    --msgbox "This is an example of whiptail. ${TEXTMESSAGE}" 10 60 
WHIP_MSG_OUT=$?

$DIALOG --title "${TITLE}" --backtitle "${BACKTITLE}" \
    --msgbox "This is an example of dialog. ${TEXTMESSAGE}" 10 60
DIALOG_MSG_OUT=$?

$WHIPTAIL --title "${TITLE}" --backtitle "${BACKTITLE}" \
    --yesno "This is an example of whiptail. ${TEXTMESSAGE}" 10 60 
WHIP_YN_OUT=$?

$DIALOG --title "${TITLE}" --backtitle "${BACKTITLE}" \
    --yesno "This is an example of dialog. ${TEXTMESSAGE}" 10 60
DIALOG_YN_OUT=$?

echo "DIALOG_MSG_OUT was ${DIALOG_MSG_OUT}, WHIP_MSG_OUT was ${WHIP_MSG_OUT}"
echo "DIALOG_YN_OUT was ${DIALOG_YN_OUT}, WHIP_YN_OUT was ${WHIP_YN_OUT}"
