#!/bin/bash

# script to dump a bunch of information about the system for debugging

# get the hostname if it's available
if [ -e /etc/hostname ]; then
    HOSTNAME=$(cat /etc/hostname)
else
    HOSTNAME="unknown_host"
fi

if [ -x "/bin/date" ]; then
    DATE_STR=$(date +%d%b%Y.%H%M)
else
    DATE_STR="unknown_date"
fi

# name of the output directory and zipfile
OUT_NAME="debug.${HOSTNAME}.${DATE_STR}"
# path to the output directory
OUT_DIR="/tmp/${OUT_NAME}"

    mkdir $OUT_DIR
    #echo "Debugging information gathered: ${DATE_STR}" > $OUT_DIR/meta.txt

    ### disk information ###
    CDROM_DEV=$(/sbin/udevadm info --query=name --name=cdrom)
    for DISK in sda sdb sdc sdd sde sdf sdg hda hdb hdc hdd;
    do
        if [ "x${DISK}" = "x${CDROM_DEV}" ]; then
            # skip querying the CD ROM device
            continue
        fi
        if [ -b /dev/${DISK} ]; then
            VENDOR=$(cat /sys/block/${DISK}/device/vendor 2>/dev/null)
            MODEL=$(cat /sys/block/${DISK}/device/model 2>/dev/null)
            echo "### Disk vendor/model: ${VENDOR} - ${MODEL} ###" \
                > $OUT_DIR/${DISK}.txt
            echo "--- fdisk: ${DISK} ---" >> $OUT_DIR/${DISK}.txt
            /sbin/fdisk -l /dev/${DISK} >> $OUT_DIR/${DISK}.txt
        fi
    done

    echo "### partition information ###" > $OUT_DIR/partitions.txt
    cat /proc/partitions >> $OUT_DIR/partitions.txt
    #cat /proc/partitions | awk '{ print $4 }' \
    #        | grep -E "hd.[1-9]$|sd.[1-9]$" >> $OUT_DIR/partitions.txt

    echo "### disk usage information ###" > $OUT_DIR/disk_usage-human.txt
    echo "### disk usage information ###" > $OUT_DIR/disk_usage-raw.txt
    for MOUNT in $(cat /proc/mounts | grep -E '/dev|^none|tmpfs|usbfs' \
        | awk '{ print $2 }' | sort);
    do
        /bin/df -h $MOUNT | grep -v "Filesystem" \
            >> $OUT_DIR/disk_usage-human.txt
        /bin/df $MOUNT | grep -v "Filesystem" >> $OUT_DIR/disk_usage-raw.txt
    done

    echo "### network information ###" > $OUT_DIR/network.txt
    /sbin/ifconfig -a >> $OUT_DIR/network.txt
    /bin/echo >> $OUT_DIR/network.txt
    /sbin/route -n >> $OUT_DIR/network.txt
    /bin/netstat -tunap >> $OUT_DIR/netstat-tunap.txt

    if [ -x /usr/bin/dpkg ]; then
        echo "### package listing ###" > $OUT_DIR/packages.txt
        #/usr/bin/dpkg -l >> $OUT_DIR
        cd /var/lib/dpkg/info/
        /bin/ls *.list | /bin/sed 's/\.list//' | sort >> $OUT_DIR/packages.txt
    fi

    if [ -x /sbin/lsmod ]; then
        echo "### Loaded kernel modules ###" > $OUT_DIR/modules.txt
        # output the header first
        /sbin/lsmod | grep "^Module" >> $OUT_DIR/modules.txt 2>&1 
        # then sort everything else and output it after the header
        /sbin/lsmod | grep -v "^Module" | sort >> $OUT_DIR/modules.txt 2>&1
    fi

    if [ -x /usr/bin/lshw ]; then
        echo "### Hardware information ###" > $OUT_DIR/lshw.txt
        /usr/bin/lshw >> $OUT_DIR/lshw.txt 2>&1
    fi

    if [ -x /usr/bin/lspci ]; then
        echo "### PCI bus information ###" > $OUT_DIR/lspci.txt
        /usr/bin/lspci -v >> $OUT_DIR/lspci.txt 2>&1
    fi

    if [ -x /usr/sbin/lsusb ]; then
        echo "### USB bus information ###" > $OUT_DIR/lsusb.txt
        /usr/sbin/lsusb -v >> $OUT_DIR/lsusb.txt 2>&1
    fi

    if [ -d /proc/asound ]; then
        echo "### ALSA sound card information ###" > $OUT_DIR/asound.txt
        cat /proc/asound/devices >> $OUT_DIR/asound.txt
    fi

    # grab dmesg as well
    echo "### dmesg (kernel ring buffer) output ###" > $OUT_DIR/dmesg.txt
    dmesg >> $OUT_DIR/dmesg.txt 2>&1

    # now zip up the files
    cd /tmp
    tar -cvf $OUT_NAME.tar $OUT_NAME
    gzip $OUT_NAME.tar

    echo "Debug information written to /tmp/${OUT_NAME}.tar.gz"
    OUT_MD5=$(md5sum /tmp/${OUT_NAME}.tar.gz)
    echo "MD5SUM of output file is:"
    echo "${OUT_MD5}"
    echo "You can use this MD5 checksum to validate the file is copied"
    echo "correctly over netcat (nc)."

exit 0
# конец!
