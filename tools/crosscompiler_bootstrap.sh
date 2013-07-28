#!/bin/sh
# crosscompiler_bootstrap.sh
# Most of this was taken from Denys Vlasenko's example at:
# http://busybox.net/~vda/HOWTO/i486-linux-uclibc/
# Changes to the original scripts are Copyright (c)2011 Brian Manning
# brian at portaboom dot com

# Notes:
# - problems building binutils-2.18
# http://anonir.wordpress.com/2010/02/05/linux-from-scratch-troubleshooting/

    # things we need to get from other places
    #BASE_URL="http://xaoc.qualcomm.com/bb_xcomp"
    BASE_URL="http://nob.pq.portaboom.com/linux/embedded/bb_xcomp"
    BINUTILS_VER="2.18"
    BINUTILS_FILE="binutils-${BINUTILS_VER}.tar.bz2"
    GCC_VER="4.3.1"
    GCC_FILE="gcc-${GCC_VER}.tar.bz2"
    #UCLIBC_VER="20080607.svn"
    UCLIBC_VER="0.9.31"
    UCLIBC_FILE="uClibc-${UCLIBC_VER}.tar.bz2"
    BUSYBOX_VER="20080607.svn"
    BUSYBOX_FILE="busybox-${BUSYBOX_VER}.tar.bz2"
    KERNEL_VER="2.6.36"
    KERNEL_FILE="linux-${KERNEL_VER}.tar.bz2"

    # things used by this script
    unset START_DIR
    APPS_DIR="/local/app"

    # source common_release_functions.sh, so that just in case there's a
    # conflict with duplicate environment variables, the variables set after
    # sourcing common_release_functions.sh take precedence
    SCRIPT_DIR=$(dirname $0)
    echo "- SCRIPT_DIR is ${SCRIPT_DIR}"
    echo "- Checking for ${SCRIPT_DIR}/common_release_functions.sh"
    if [ -r ${SCRIPT_DIR}/common_release_functions.sh ]; then
        source ${SCRIPT_DIR}/common_release_functions.sh
    else
        echo "ERROR: can't find 'lack_functions.sh' script"
        echo "My name is: $0"
        exit 1
    fi # if [ -r ${SCRIPT_DIR}/lack_functions.sh ]

    # are we debugging?
    if [ "x$DEBUG" = "x" ]; then
        export DEBUG=0
    fi

    # locations of binaries used by this script
    TRUE=$(which true)
    GETOPT=$(which getopt)
    MV=$(which mv)
    CAT=$(which cat)
    RM=$(which rm)
    MKTEMP=$(which mktemp)
    GZIP=$(which gzip)
    SED=$(which sed)
    TOUCH=$(which touch)
    DATE=$(which date)
    RFC_2822_DATE=$(${DATE} --rfc-2822)

### BEGIN SCRIPT FUNCTIONS ###

## FUNC: link
function link() {
    echo "Making $1 -> $2..."
    local answer=""
    test ! -L "$1" -a -d "$1" && {
    # Asked to make /a/b/c/d -> somewhere, but d exists and is a dir?!
    echo -n " $1 is a directory! I am confused.
I will create a symlink INSIDE it. Probably this isn't what you want.
Press <Enter>/[S]kip/Ctrl-C: ";
    read answer
    }
    test "$answer" != s -a "$answer" != S && {
    sudo ln -sfn "$2" "$1" || { echo -n " failed. Press <Enter>: "; read junk; }
    }
}

function make_stub() {
    echo "Making $1 -> $2..."
    rm -f "$1"
    # messy, isn't it? :-)
    echo  >"$1" "#!/bin/sh"
    echo >>"$1" "cd '$(dirname  \"$2\")'"
    # above:     cd '/path to/exec img'"
    echo >>"$1" "exec './$(basename \"$2\")'" '"$@"'
    # above:     exec './executable name' "$@"
    chmod a+x "$1"
}

function make_stub_abs() {
    echo "Making $1 -> $2..."
    rm -f "$1"
    echo  >"$1" "#!/bin/sh"
    echo >>"$1" "exec '$2'" "$@"
    chmod a+x "$1"
}

function make_stub_samename() {
    for fn in $2; do
        if test -e "$fn"; then
        bn=$(basename "$fn")
        mkdir -p "$1" 2>/dev/null
        make_stub "$1/$bn" "$fn"
    fi
    done
}

function make_stub_samename_abs() {
    for fn in $2; do
        if test -e "$fn"; then
        bn=$(basename "$fn")
        sudo mkdir -p "$1" 2>/dev/null
        make_stub_abs "$1/$bn" "$fn"
    fi
    done
}

function link_samename() {
    for fn in $2; do
        if test -e "$fn"; then
        bn=$(basename "$fn")
        sudo mkdir -p "$1" 2>/dev/null
        link "$1/$bn" "$fn"
    fi
    done
}

function link_samename_strip() {
    sudo strip $2
    for fn in $2; do
        if test -e "$fn"; then
        bn=$(basename "$fn")
        sudo mkdir -p "$1" 2>/dev/null
        link "$1/$bn" "$fn"
    fi
    done
}

function link_samename_r() {
    for fn in $2; do
        if test -e "$fn"; then
        bn=$(basename "$fn")
        if test -f "$fn"; then
            # File: Make link with the same name in $1
        sudo mkdir -p "$1" 2>/dev/null
            link "$1/$bn" "$fn"
        elif test -d "$fn"; then
            # Dir: Descent into subdirs
        sudo mkdir -p "$1" 2>/dev/null
            link_samename_r "$1/$bn" "$fn/*"
        fi
    fi
    done
}

function link_samename_r_strip() {
    sudo strip $2
    for fn in $2; do
    bn=$(basename "$fn")
    if test -f "$fn"; then
        # File: Make link with the same name in $1
        mkdir -p "$1" 2>/dev/null
        link "$1/$bn" "$fn"
    elif test -d "$fn"; then
        # Dir: Descent into subdirs
        mkdir -p "$1" 2>/dev/null
        link_samename_r_strip "$1/$bn" "$fn/*"
    fi
    done
}

function link_samename_r_gz() {
    gzip -9 $2
    for fn in $2; do
        if test -e "$fn"; then
        bn=$(basename "$fn")
        if test -f "$fn"; then
            # File: Make link with the same name in $1
        mkdir -p "$1" 2>/dev/null
            link "$1/$bn" "$fn"
        elif test -d "$fn"; then
            # Dir: Descent into subdirs
        mkdir -p "$1" 2>/dev/null
            link_samename_r_gz "$1/$bn" "$fn/*"
        fi
    fi
    done
}

# usage: link_man_r_gz /usr/man /path/to/man
function link_man_r_gz() {
    # we'll work relative to /path/to/man
    ( cd "$2" || exit 1
    # process all manpages (gzip 'em)
    for a in *.[0123456789]; do
    if test -L "$a"; then
        link=$(linkname "$a")
        base=${link%.[0123456789]}
        if test "$link" != "$base"; then
        echo "Replacing link $a->$link by $a.gz->$link.gz"
        link "$a.gz" "$link.gz"
        rm "$a"
        else
        echo -n "Strange link: $a->$link. Ignored. Press <Enter>:"
        read junk
        continue
        fi
        elif test ! -e "$a"; then # this catches 'no *.n files here'
        break
    elif test -f "$a"; then
        rm "$a.gz"
        gzip -9 "$a"
    elif test -d "$a"; then
        continue
    else
        echo -n "Strange object: $a. Ignored. Press <Enter>:"
        read junk
        continue
    fi
    done
    # link all existing .gz
    for a in *.[0123456789].gz; do
        if test ! -e "$a"; then break; fi
    mkdir -p "$1" 2>/dev/null
    link "$1/$a" "$(pwd)/$a"
    done
    # for each dir: descend into
    for a in *; do
        if test ! -e "$a"; then break; fi
    if test -d "$a"; then
        mkdir -p "$1" 2>/dev/null
            link_man_r_gz "$1/$a" "$(pwd)/$a"
    fi
    done
    )
}

## FUNC: make_tempdir
function make_tempdir () {
    local START_DIR=$1

    if [ $(echo ${START_DIR} | grep -c '^/') -eq 0 ]; then
        echo "ERROR: temporary directory must be an absolute path"
        echo "(path must start with leading slash '/')"
        exit 1
    fi
    if [ -e $START_DIR/stamp.tempdir ]; then
        BB_TEMP_DIR=$START_DIR
        echo "- Reusing temporary directory '${BB_TEMP_DIR}'"
    else
        # create a temp directory
        export BB_TEMP_DIR=$(${MKTEMP} -d ${START_DIR}/bb_temp_dir.XXXXX)
        check_exit_status $? "Creating temporary directory in ${START_DIR}"
        echo "- Created temporary directory '${BB_TEMP_DIR}'"
        touch ${BB_TEMP_DIR}/stamp.tempdir
    fi
    export BB_TEMP_DIR
} # make_tempdir ()

## FUNC: sudo_update_timestamp
function sudo_update_timestamp() {
    sudo -v
} # function sudo_update_timestamp

## FUNC: sudo_start_message
function sudo_start_message() {
    echo "SUDO access is usually required for installing cross-compile tools"
    echo "Will now run the command 'sudo -v' to update SUDO timestamp."
    echo "Please type your SUDO password when prompted,"
    echo "or hit Ctrl-C if you are unsure you want to run this script;"
    sudo_update_timestamp
} # function sudo_start_message

## FUNC: generic_make
function generic_make () {
    echo "======= generic_make =======" | tee -a $BB_BUILD_LOG
    echo "current directory is ${PWD}" | tee -a $BB_BUILD_LOG
    pause_prompt
    make "$@" 2>&1 | tee -a $BB_BUILD_LOG
    check_exit_status $? "generic make in ${PWD}"
    return 0
} # function generic_make

## FUNC: binutils_configure
function binutils_configure () {
    echo "======= binutils_configure =======" | tee -a $BB_BUILD_LOG
    if ! [ -d "binutils-${BINUTILS_VER}" ]; then
        echo "- downloading/unpacking ${BINUTILS_FILE}"
        if [ $DEBUG -gt 0 ]; then
            TAR_OPTS="-jxvf"
        else
            TAR_OPTS="-jxf"
        fi
        wget -q -O - -a $BB_BUILD_LOG $BASE_URL/$BINUTILS_FILE \
            | tar $TAR_OPTS - \
            | tee -a $BB_BUILD_LOG
    fi
    echo "- changing directory to binutils-${BINUTILS_VER}"|tee -a $BB_BUILD_LOG
    if [ -d binutils-${BINUTILS_VER} ]; then
        cd binutils-${BINUTILS_VER}
        # if the .obj directory exists, we've been here before; don't run
        # configure
        if ! [ -e ${BB_TEMP_DIR}/stamp.binutils.configure ]; then
            pause_prompt
            mkdir .obj-i486-linux-uclibc
            cd .obj-i486-linux-uclibc
            # run configure
            SRC=..
            CROSS=$(basename "$PWD")
            # removes .obj- from the front of $CROSS
            CROSS="${CROSS#.obj-}"
            # the name of the output directory?
            NAME=$(cd $SRC;pwd)
            NAME=$(basename "$NAME")-$CROSS
            echo "- NAME is ${NAME}"
            STATIC_DIR=/local/app/$NAME
            echo "- Running ./configure for binutils" >> $BB_BUILD_LOG
            $SRC/configure \
                --prefix=$STATIC_DIR \
                --exec-prefix=$STATIC_DIR \
                --bindir=/usr/bin \
                --sbindir=/usr/sbin \
                --libexecdir=$STATIC_DIR/libexec \
                --datadir=$STATIC_DIR/share \
                --sysconfdir=/etc \
                --sharedstatedir=$STATIC_DIR/var/com \
                --localstatedir=$STATIC_DIR/var \
                --libdir=/usr/lib \
                --includedir=/usr/include \
                --infodir=/usr/info \
                --mandir=/usr/man \
                \
                --oldincludedir=/usr/include \
                --target=$CROSS \
                --with-sysroot=/usr/cross/$CROSS \
                --disable-rpath \
                --disable-nls \
                --enable-werror=no \
                2>&1 | tee -a $BB_BUILD_LOG
                check_exit_status $? "binutils configure"
        else
            if [ -d .obj-i486-linux-uclibc ]; then
                echo "- Skipping 'configure' for binutils; stampfile exists"
                cd .obj-i486-linux-uclibc
            else
                echo "ERROR: binutils stampfile exists, but directory"
                echo "ERROR: .obj-i486-linux-uclibc does not exist"
                exit 1
            fi # if [ -d .obj-i486-linux-uclibc ]
        fi # if ! [ -d .obj-i486-linux-uclibc ]
        touch ${BB_TEMP_DIR}/stamp.binutils.configure
    else
        echo "binutils-${BINUTILS_VER} failed to download/unpack properly"
        exit 1
    fi # if [ -d binutils-${BINUTILS_VER} ]
} # function binutils_configure

## FUNC: binutils_make_install
function binutils_make_install() {
    echo "======= binutils_make_install =======" | tee -a $BB_BUILD_LOG
    echo "- current directory is ${PWD}" | tee -a $BB_BUILD_LOG
    if ! [ -e ${BB_TEMP_DIR}/stamp.binutils.make.install ]; then
        pause_prompt
        SRC=..
        CROSS=$(basename "$PWD")
        CROSS="${CROSS#.obj-}"
        NAME=$(cd $SRC;pwd)
        NAME=$(basename "$NAME")-$CROSS
        STATIC=/local/app/$NAME
        sudo make \
        prefix=$STATIC \
        exec-prefix=$STATIC \
        bindir=$STATIC/bin \
        sbindir=$STATIC/sbin \
        libexecdir=$STATIC/libexec \
        datadir=$STATIC/share \
        sysconfdir=$STATIC/var_template/etc \
        sharedstatedir=$STATIC/var_template/com \
        localstatedir=$STATIC/var_template \
        libdir=$STATIC/lib \
        includedir=$STATIC/include \
        infodir=$STATIC/info \
        mandir=$STATIC/man \
        install 2>&1 | tee -a $BB_BUILD_LOG
        check_exit_status $? "binutils make install"
        touch $BB_TEMP_DIR/stamp.binutils.make.install
    else
        echo "- Skipping 'make install' for binutils; stampfile exists"
    fi
} # function binutils_make_install ()

function binutils_make_symlinks() {
    echo "======= binutils_make_symlinks =======" | tee -a $BB_BUILD_LOG
    echo "- changing to Apps directory"
    cd $APPS_DIR/binutils-${BINUTILS_VER}-*
    echo "- current directory is ${PWD}" | tee -a $BB_BUILD_LOG
    if ! [ -e ${BB_TEMP_DIR}/stamp.binutils.make.symlinks ]; then
        pause_prompt
        NAME=$(basename "$PWD")
        VER=-$(echo $NAME | cut -d '-' -f 2-99)
        echo "- ver is $VER" | tee -a $BB_BUILD_LOG
        NAME=$(echo $NAME | cut -d '-' -f 1)
        echo "- name is $NAME" | tee -a $BB_BUILD_LOG
        CROSS=$(basename $PWD | cut -d '-' -f 3-99)
        echo "- cross is $CROSS" | tee -a $BB_BUILD_LOG
        STATIC=/local/app/$NAME$VER

        test "${STATIC%$CROSS}" = "$STATIC" && {
            echo 'Wrong $CROSS in '"$0"; exit 1; }

        sudo mkdir -p /local/cross/$CROSS/bin
        sudo mkdir -p /local/cross/$CROSS/lib
        # Don't want to deal with pairs of usr/bin/ and bin/, usr/lib/ and lib/
        # in /usr/cross/$CROSS. This seems to be the easiest fix:
        sudo ln -s . /local/cross/$CROSS/usr

        # Do we really want to install tclsh8.4 and wish8.4 though? What are
        # those btw?
        link_samename_strip     /usr/bin                "$STATIC/bin/*"
        link_samename_strip     /local/cross/$CROSS/bin   "$STATIC/$CROSS/bin/*"
        # elf2flt.ld and ldscripts/*. Actually seems to work just fine
        # without ldscripts/* symlinked, but elf2flt does insist.
        link_samename           /local/cross/$CROSS/lib   "$STATIC/$CROSS/lib/*"
        touch $BB_TEMP_DIR/stamp.binutils.make.symlinks
    else
        echo "- Skipping 'make install' for gcc; stampfile exists" \
            | tee -a $BB_BUILD_LOG
    fi # if ! [ -e ${BB_TEMP_DIR}/stamp.gcc.make.symlinks ]

} # function binutils_make_symlinks

## FUNC: gcc_configure
function gcc_configure () {
    echo "======= gcc_configure =======" | tee -a $BB_BUILD_LOG
    echo "current directory is ${PWD}" | tee -a $BB_BUILD_LOG
    if ! [ -d "gcc-${GCC_VER}.obj-i486-linux-uclibc" ]; then
        pause_prompt
        echo "- downloading/unpacking ${GCC_FILE}"
        if [ $DEBUG -gt 0 ]; then
            TAR_OPTS="-jxvf"
        else
            TAR_OPTS="-jxf"
        fi
        wget -q -O - -a $BB_BUILD_LOG $BASE_URL/$GCC_FILE \
            | tar $TAR_OPTS - \
            | tee -a $BB_BUILD_LOG
        mkdir gcc-${GCC_VER}.obj-i486-linux-uclibc
    fi
    echo "changing directory to ${PWD}/gcc-${GCC_VER}.obj-i486-linux-uclibc" \
        >> $BB_BUILD_LOG
    cd gcc-${GCC_VER}.obj-i486-linux-uclibc
    # if the .obj directory exists, we've been here before; don't run
    # configure
    if ! [ -e ${BB_TEMP_DIR}/stamp.gcc.configure ]; then
        # run configure
        CROSS=$(basename "$PWD" | cut -d- -f3-99)
        echo "CROSS is ${CROSS}" | tee -a $BB_BUILD_LOG
        SRC=../$(basename "$PWD" .obj-$CROSS)
        echo "SRC is ${SRC}" | tee -a $BB_BUILD_LOG
        NAME=$(cd $SRC;pwd)
        NAME=$(basename "$NAME" .obj-$CROSS)-$CROSS
        echo "NAME is ${NAME}" | tee -a $BB_BUILD_LOG
        STATIC=/local/app/$NAME

        $SRC/configure \
        --prefix=$STATIC                                \
        --exec-prefix=$STATIC                           \
        --bindir=$STATIC/bin                            \
        --sbindir=$STATIC/sbin                          \
        --libexecdir=$STATIC/libexec                    \
        --datadir=$STATIC/share                         \
        --sysconfdir=/etc                               \
        --sharedstatedir=$STATIC/var/com                \
        --localstatedir=$STATIC/var                     \
        --libdir=$STATIC/lib                            \
        --includedir=$STATIC/include                    \
        --infodir=$STATIC/info                          \
        --mandir=$STATIC/man                            \
        --disable-nls                                   \
        \
        --with-local-prefix=/usr/local                  \
        --with-slibdir=$STATIC/lib                      \
        \
        --target=$CROSS                                 \
        --with-gnu-ld                                   \
        --with-ld="/usr/bin/$CROSS-ld"                  \
        --with-gnu-as                                   \
        --with-as="/usr/bin/$CROSS-as"                  \
        \
        --with-sysroot=/local/cross/$CROSS                \
        \
        --enable-languages="c"                          \
        --disable-shared                                \
        --disable-threads                               \
        --disable-tls                                   \
        --disable-multilib                              \
        --disable-decimal-float                         \
        --disable-libgomp                               \
        --disable-libssp                                \
        --disable-libmudflap                            \
        --without-headers                               \
        --with-newlib                                   \
        \
        2>&1 | tee -a $BB_BUILD_LOG
        check_exit_status $? "gcc configure"
    else
        echo "- Skipping 'configure' for gcc; stampfile exists" \
            | tee -a $BB_BUILD_LOG
    fi # if ! [ -e ${BB_TEMP_DIR}/stamp.gcc.configure ]
    touch ${BB_TEMP_DIR}/stamp.gcc.configure
} # function binutils_configure

function gcc_make () {
    echo "======= gcc_make =======" | tee -a $BB_BUILD_LOG
    echo "- current directory is ${PWD}" | tee -a $BB_BUILD_LOG
    if ! [ -e ${BB_TEMP_DIR}/stamp.gcc.make ]; then
        pause_prompt
        CROSS=$(basename "$PWD" | cut -d- -f3-99)
        echo "CROSS is ${CROSS}" | tee -a $BB_BUILD_LOG
        # "The directory that should contain system headers does not exist:
        # /usr/cross/foobar/usr/include"
        sudo mkdir -p /local/cross/$CROSS/usr/include

        make "$@" 2>&1 | tee -a $BB_BUILD_LOG
        check_exit_status $? "gcc make"
        touch $BB_TEMP_DIR/stamp.gcc.make
    else
        echo "- Skipping 'make' for gcc; stampfile exists" \
            | tee -a $BB_BUILD_LOG
    fi # if ! [ -e ${BB_TEMP_DIR}/stamp.gcc.make.install ]
} # function gcc_make

function gcc_make_install () {
    echo "======= gcc_make_install =======" | tee -a $BB_BUILD_LOG
    echo "- current directory is ${PWD}" | tee -a $BB_BUILD_LOG
    if ! [ -e ${BB_TEMP_DIR}/stamp.gcc.make.install ]; then
        pause_prompt
        CROSS=$(basename "$PWD" | cut -d- -f3-99)
        echo "CROSS is ${CROSS}" | tee -a $BB_BUILD_LOG
        SRC=../$(basename "$PWD" .obj-$CROSS)
        echo "SRC is ${SRC}" | tee -a $BB_BUILD_LOG
        NAME=$(cd $SRC;pwd)
        NAME=$(basename "$NAME" .obj-$CROSS)-$CROSS
        echo "NAME is ${NAME}" | tee -a $BB_BUILD_LOG
        STATIC=/local/app/$NAME

        sudo make -k \
        prefix=$STATIC                          \
        exec-prefix=$STATIC                     \
        bindir=$STATIC/bin                      \
        sbindir=$STATIC/sbin                    \
        libexecdir=$STATIC/libexec              \
        datadir=$STATIC/share                   \
        sysconfdir=$STATIC/var_template/etc     \
        sharedstatedir=$STATIC/var_template/com \
        localstatedir=$STATIC/var_template      \
        libdir=$STATIC/lib                      \
        includedir=$STATIC/include              \
        infodir=$STATIC/info                    \
        mandir=$STATIC/man                      \
        install 2>&1 | tee -a $BB_BUILD_LOG
        check_exit_status $? "gcc make install"
        touch $BB_TEMP_DIR/stamp.gcc.make.install
    else
        echo "- Skipping 'make install' for gcc; stampfile exists" \
            | tee -a $BB_BUILD_LOG
    fi
} # function gcc_make_install

function gcc_make_symlinks() {
    echo "======= gcc_make_symlinks =======" | tee -a $BB_BUILD_LOG
    echo "- changing to Apps directory"
    cd $APPS_DIR/gcc-${GCC_VER}-*
    echo "- current directory is ${PWD}" | tee -a $BB_BUILD_LOG
    if ! [ -e ${BB_TEMP_DIR}/stamp.gcc.make.symlinks ]; then
        pause_prompt
        NAME=$(basename "$PWD")
        VER=-$(echo $NAME | cut -d '-' -f 2-99)
        echo "- ver is $VER"
        NAME=$(echo $NAME | cut -d '-' -f 1)
        echo "- name is $NAME"
        CROSS=$(basename $PWD | cut -d '-' -f 3-99)
        echo "- cross is $CROSS"
        STATIC=/local/app/$NAME$VER

        test "${STATIC%$CROSS}" = "$STATIC" && {
            echo 'Wrong $CROSS in '"$0"; exit 1; }
        # Strip executables anywhere in the tree
        # grep guards against matching files like *.o, *.so* etc
        sudo strip $(find -perm +111 -type f | grep '/[a-z0-9]*$' | xargs)
        # symlink binaries
        link_samename_strip /usr/bin                "$STATIC/bin/*"
        # symlink libs
        link_samename /usr/cross/$CROSS/lib         "$STATIC/$CROSS/lib/*"
        # symlink includes
        link_samename /usr/cross/$CROSS/include/c++ \
            "$STATIC/$CROSS/include/c++/*"
        touch $BB_TEMP_DIR/stamp.gcc.make.symlinks
    else
        echo "- Skipping 'make install' for gcc; stampfile exists" \
            | tee -a $BB_BUILD_LOG
    fi # if ! [ -e ${BB_TEMP_DIR}/stamp.gcc.make.symlinks ]
} # function gcc_make_symlinks

function uclibc_kernel_download() {
    echo "======= uclibc_kernel_download =======" | tee -a $BB_BUILD_LOG
    echo "- current directory is ${PWD}" | tee -a $BB_BUILD_LOG
    if ! [ -d "uClibc-${UCLIBC_VER}" ]; then
        echo "- downloading/unpacking ${UCLIBC_FILE}"
        if [ $DEBUG -gt 0 ]; then
            TAR_OPTS="-jxvf"
        else
            TAR_OPTS="-jxf"
        fi
        wget -q -O - -a $BB_BUILD_LOG $BASE_URL/$UCLIBC_FILE \
            | tar $TAR_OPTS - \
            | tee -a $BB_BUILD_LOG
        touch $BB_TEMP_DIR/stamp.uclibc.unpack
    fi
    if [ -d "uClibc-${UCLIBC_VER}" ]; then
        cd "uClibc-${UCLIBC_VER}"
        echo "- current directory is ${PWD}" | tee -a $BB_BUILD_LOG
        if ! [ -d "linux-${KERNEL_VER}" ]; then
            echo "- downloading/unpacking kernel source ${KERNEL_FILE}" \
                | tee -a $BB_BUILD_LOG
            if [ $DEBUG -gt 0 ]; then
                TAR_OPTS="-jxvf"
            else
                TAR_OPTS="-jxf"
            fi
            wget -q -O - -a $BB_BUILD_LOG $BASE_URL/$KERNEL_FILE \
                | tar $TAR_OPTS - \
                | tee -a $BB_BUILD_LOG
            if [ -d "linux-${KERNEL_VER}" ]; then
                cd "linux-${KERNEL_VER}"
                make ARCH=i386 CROSS_COMPILE=i486-linux-uclibc- defconfig 2>&1 \
                    | tee -a $BB_BUILD_LOG
                ln -s asm-x86 include/asm
                make ARCH=i386 CROSS_COMPILE=i486-linux-uclibc- \
                    headers_install 2>&1 \
                    | tee -a $BB_BUILD_LOG
                touch $BB_TEMP_DIR/stamp.uclibc.kernel.unpack
                # remove the unneeded source code directories
                for DIR in arch block COPYING CREDITS crypto Documentation \
                    drivers firmware fs include init ipc Kbuild kernel \
                    lib MAINTAINERS Makefile mm net README REPORTING-BUGS \
                    samples scripts security sound tools virt;
                do
                    rm -rf $DIR
                done
                cd ..
            else
                echo "ERROR: kernel source did not download/unpack"
                exit 1
            fi # if [ -d "linux-${KERNEL_VER}" ]
        fi # if ! [ -d "uclibc-${UCLIBC_VER}/linux-${KERNEL_VER}" ]
    else
        echo "ERROR: failed to download/unpack uclibc-${UCLIBC_VER}"
        exit 1
    fi
    # don't change back to BB_TEMP_DIR, we need to run generic_make next
    echo "HEY! Copy the .config file for uclibc into $PWD/uclibc-${UCLIBC_VER}"
    pause_prompt
} # function uclibc_download

function uclibc_make_install() {
    echo "======= uclibc_make_install =======" | tee -a $BB_BUILD_LOG
    #cd "${BB_TEMP_DIR}/uClibc-${UCLIBC_VER}"
    echo "- current directory is ${PWD}" | tee -a $BB_BUILD_LOG
    # FIXME check for uclibc.make.install stamp
    #if [ -d "uClibc-${UCLIBC_VER}" ]; then
    #    cd "uClibc-${UCLIBC_VER}"
        {
            sudo make install || exit 1
            # target no longer exists in newer versions of uClibc
            #sudo make install_kernel_headers || exit 1
        } 2>&1 | tee -a $BB_BUILD_LOG
        cd ..
        touch $BB_TEMP_DIR/stamp.uclibc.make.install
    #else
    #    echo "ERROR: uClibc directory 'uClibc-${UCLIBC_VER}' missing"
    #    echo "ERROR: from ${PWD}"
    #    exit 1
    #fi # if [ -d "uclibc-${UCLIBC_VER}" ]
    return 0
} # function uclibc_make_install

function uclibc_make_symlinks() {
    echo "======= uclibc_make_symlinks =======" | tee -a $BB_BUILD_LOG
    echo "- changing to Apps directory"
    cd $APPS_DIR/uClibc-${UCLIBC_VER}-*
    echo "- current directory is ${PWD}" | tee -a $BB_BUILD_LOG
    if ! [ -e ${BB_TEMP_DIR}/stamp.uclibc.make.symlinks ]; then
        pause_prompt
        NAME=$(basename "$PWD")
        VER=-$(echo $NAME | cut -d '-' -f 2-99)
        echo "- ver is $VER"
        NAME=$(echo $NAME | cut -d '-' -f 1)
        echo "- name is $NAME"
        CROSS=$(basename $PWD | cut -d '-' -f 3-99)
        echo "- cross is $CROSS"
        ARCH=`echo $NAME$VER | cut -d- -f3 | sed -e 's/i.86/i386/'`
        echo "- arch is $ARCH"
        STATIC=/local/app/$NAME$VER

        sudo mkdir -p /local/cross/$CROSS/lib
        sudo mkdir -p /local/cross/$CROSS/include
        # symlink libs
        link_samename /local/cross/$CROSS/lib     "$STATIC/$ARCH/usr/lib/*"
        # # symlink includes
        link_samename /local/cross/$CROSS/include "$STATIC/$ARCH/usr/include/*"
        touch $BB_TEMP_DIR/stamp.uclibc.make.symlinks
    else
        echo "- Skipping making symlinks for uclibc; stampfile exists" \
            | tee -a $BB_BUILD_LOG
    fi # if ! [ -e ${BB_TEMP_DIR}/stamp.gcc.make.symlinks ]
    return 0
} # function uclibc_make_symlinks

### MAIN SCRIPT ###
    PAUSE_PROMPT=1
    SCRIPT_NAME=$(basename $0)
    export START_DIR=$PWD
    if [ "x$1" = "x" ]; then
        echo "ERROR: no working directory passed as an argument"
        echo "Usage: ${SCRIPT_NAME} /path/to/working/directory"
        exit 1
    fi # if [ "x$1" = "x" ]
    make_tempdir $1
    sudo_start_message
    # things we need to use for this script
    export BB_BUILD_LOG="${BB_TEMP_DIR}/build.log"
    : > $BB_BUILD_LOG
    echo "======= BEGIN crosscompiler_bootstrap.sh =======" \
        | tee -a $BB_BUILD_LOG
    # binutils
    cd $BB_TEMP_DIR
    binutils_configure
    generic_make
    sudo_update_timestamp
    binutils_make_install
    binutils_make_symlinks
    # gcc
    cd $BB_TEMP_DIR
    gcc_configure
    sudo_update_timestamp
    gcc_make
    gcc_make_install
    gcc_make_symlinks
    cd $BB_TEMP_DIR
    uclibc_kernel_download
    generic_make
    uclibc_make_install
    uclibc_make_symlinks
exit 0
# конец!
