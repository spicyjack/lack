#!/bin/sh

# script for making the Antlinux ISO image

# see the erolotus mkisofs script for ideas on mapping directories in different
# parts of the filesystem to the ISO image

# capture the date, use in the volume name
DATE=$(date +%d%h%Y)

/usr/bin/mkisofs -r -T -v -J \
-A "Antlinux" \
-P "http://www.antlinux.com" \
-p "Brian Manning" \
-V "antlinux-${DATE}" \
-m lost+found \
-m TRANS.TBL \
-b isolinux/isolinux.bin \
-c isolinux/boot.cat \
-no-emul-boot -boot-load-size 4 -boot-info-table \
-o /local/mnt/workspace/antlinux-${DATE}.iso \
$1

# -r -T -v -J | Rock Ridge, Trans.Tbl, verbose, Joliet, and include all files
# -A | Application name
# -P | Publisher ID
# -p | Person responsible
# -x | exclude file/directory
# -b | boot image is boot.img
# -c | catalog file created	
# -o | ISO image to create
# -V | Volume ID
# directory or file to create it from	 
#-b boot/cdboot.288 \
#-c boot/catalog \
#-c boot.cat \
#-b images/boot.img \
# mkisofs -a -b images/boot.img -c boot.catalog -A "Redhat 6.0" -f -d -D -J
# -l -L -p "Neil Schneider" -P "http://www.linuxgeek.net" -r -R -T -x lost+found
# -o image.raw /misc/i386
