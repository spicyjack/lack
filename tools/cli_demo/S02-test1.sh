#!/bin/sh

action () {
    TOTAL_SCRIPTS=$1
    CURRENT_SCRIPT_NUM=$2
    echo -n "this is $0, aka S02-test1.sh; script $CURRENT_SCRIPT_NUM "
    echo "out of $TOTAL_SCRIPTS total scripts"
    BACKTITLE="Project Naranja Installer: "
    BACKTITLE="$BACKTITLE Step $CURRENT_SCRIPT_NUM of $TOTAL_SCRIPTS"
    $DIALOG --ok-label "Next" \
        --backtitle "$BACKTITLE" --title "Test Screen #1" \
        --msgbox "Do you want to advance to the next screen?" 10 60
    return $?
}
