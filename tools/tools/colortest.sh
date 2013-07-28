#!/bin/bash

# gain the colorize() function, with colors
# $1 foreground, $2 background, $3 text to colorize
source ../common/initscripts/lack_functions.sh

# do some test text
colorize "${BOLD};${F_YLW};${B_GRN}" "This is some test text"; echo
colorize "${SUCCESS}" "This is a success message"; echo
colorize "${FAILURE}" "This is a failure message"; echo
colorize "${INFO}" "This is an info message"; echo
colorize "${TIP}" "This is a tip"; echo
colorize "${T_SUCCESS}" "This is a success message"; echo
colorize "${T_FAILURE}" "This is a failure message"; echo
colorize "${T_INFO}" "This is an info message"; echo
colorize "${T_TIP}" "This is a tip"; echo


# fin
exit 0
