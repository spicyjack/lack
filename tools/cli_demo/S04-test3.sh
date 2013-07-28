#!/bin/sh

action () {
    TOTAL_SCRIPTS=$1
    CURRENT_SCRIPT_NUM=$2
    echo -n "this is $0, aka S04-test3.sh; script $CURRENT_SCRIPT_NUM "
    echo "out of $TOTAL_SCRIPTS total scripts"
    BACKTITLE="Project Naranja Installer: "
    BACKTITLE="$BACKTITLE Step $CURRENT_SCRIPT_NUM of $TOTAL_SCRIPTS"
    $DIALOG --yes-label "Next" --no-label "Previous" \
        --backtitle "$BACKTITLE" --title "Test Screen #3" \
        --yesno "Do you want to advance to the next screen?" 10 60
    return $?
}
