#!/bin/sh

# grab a list of window managers from debian, get their installed size and
# sort
for WM in $(apt-cache search window-manager | awk '{print $1}'\
    | egrep -v "extra$|dev$|bin$|icccm0$|xorg$|menu$"); 
do 
    SIZE=$(apt-cache show $WM | grep "Installed-Size" \
        | sed 's/^Installed-Size: //'); 
    echo "$WM: ${SIZE}k"; 
done | sort -n -k 2
