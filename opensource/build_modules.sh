#!/bin/bash

set -ex

MODULES="curl dbus fcgi libupnp net-snmp openssl zlib"

ARCHITECTURES="pc intel_usg"
BOARDS_PC="rdkb"
BOARDS_INTEL_USG="dpc3939_arm dpc3939b_arm dpc3941_arm intel_usg_atom rdkb_arm rdkb_atom"

function usage
{
	echo "$1 <Architecture> <Board> build|clean|clobber"
	echo "	Supported Architectures: $ARCHITECTURES"
	echo "	Supported Boards for pc: $BOARDS_PC"
	echo "	Supported Boards for intel_usg: $BOARDS_INTEL_USG"
	exit
}

function decorate_log
{
	echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	echo "$1"
	echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
}

if [ $# -lt 3 ]; then
	usage $0
fi

ARCH=$1
BOARD=$2
BUILD_TYPE=$3

# Generic
PREFIX_DIR="${CCSP_OPENSOURCE_DIR}"
PREFIX="--prefix=${PREFIX_DIR}"

# Build Flags
build_dbus=1
build_snmp=1
build_openssl=1
build_curl=1
build_fcgi=1
build_upnp=1
build_zlib=1


# Package Specific Variables
DBUS_CONFIGURE="--disable-tests --enable-verbose-mode --disable-selinux --disable-checks 
					--with-x=no --with-pic=yes ${PREFIX}"
SNMP_CONFIGURE="--disable-embedded-perl --disable-perl-cc-checks --disable-perl 
					--without-perl-modules ${PREFIX} --with-openssl=${PREFIX_DIR}"
OPENSSL_CONFIGURE="${PREFIX} shared no-bf no-cast no-idea no-rc2 no-rc4 no-rc5 no-md2 
					no-md4 no-mdc2 no-ripemd no-engines"
CURL_CONFIGURE=" --disable-static ${PREFIX} --without-zlib --with-ssl=${PREFIX_DIR}"
FCGI_CONFIGURE=" ${PREFIX}"
UPNP_CONFIGURE=" ${PREFIX}"
ZLIB_CONFIGURE=" ${PREFIX}"

if [ ! -e ${PREFIX_DIR} ]; then
	decorate_log "Creating Directory: ${PREFIX_DIR}"
	mkdir -p ${PREFIX_DIR}
fi

case "$ARCH" in
"pc")
	CFLAGS_ARG="-fPIC"
	LDFLAGS_ARG="-fPIC"
	CROSS_COMPILE=""
	DBUS_CONFIGURE="$DBUS_CONFIGURE CFLAGS=${CFLAGS_ARG} LDFLAGS=${LDFLAGS_ARG}"
	SNMP_CONFIGURE="$SNMP_CONFIGURE CPPFLAGS=${CFLAGS_ARG} CFLAGS=${CFLAGS_ARG} LDFLAGS=${LDFLAGS_ARG}"
	if [ `uname -m` == "x86_64" ]; then
		OPENSSL_CONFIGURE="linux-generic64 $OPENSSL_CONFIGURE"
	else
		OPENSSL_CONFIGURE="linux-generic32 $OPENSSL_CONFIGURE"
	fi
	;;
"intel_usg")
	HOST="${CROSS_COMPILE:0:${#CROSS_COMPILE}-1}"
	CROSS_COMPILE="${CROSS_COMPILE}"
	HOST_ARG="--host=${HOST}"
	TARGET_ARG=`uname -m`-linux
	CFLAGS_ARG="-fPIC -I${SDK_PATH}/ti/include"
	LDFLAGS_ARG="-fPIC -L${SDK_PATH}/ti/lib -L${SDK_PATH}/build/vgwsdk/fs/gw/lib"
	DBUS_CONFIGURE="$HOST_ARG $DBUS_CONFIGURE"
	SNMP_CONFIGURE="$HOST_ARG $TARGET_ARG --with-openssl=${PREFIX_DIR} $SNMP_CONFIGURE"
	OPENSSL_CONFIGURE="linux-generic32 $OPENSSL_CONFIGURE"
	CURL_CONFIGURE="$HOST_ARG $CURL_CONFIGURE"
	FCGI_CONFIGURE="$HOST_ARG $FCGI_CONFIGURE"
	UPNP_CONFIGURE="$HOST_ARG $UPNP_CONFIGURE"
	ZLIB_CONFIGURE=" $ZLIB_CONFIGURE"

	# if compiling for atom only dbus is needed, disable other opensource components
	if [[ $BOARD == *atom* ]]; then
		build_snmp=0; build_openssl=0; build_curl=0; build_fcgi=0; build_upnp=0; build_zlib=0;
		CFLAGS_ARG="-fPIC -I${SDK_PATH}/include"
		LDFLAGS_ARG="-fPIC -L${SDK_PATH}/lib"
	fi
	;;
*)
	usage $0;;
esac

OPENSOURCE_WORK_DIR=$CCSP_ROOT_DIR/ExtDependency/opensource_work/$ARCH/$BOARD
OPENSOURCE_PROGRESS_DIR=${OPENSOURCE_WORK_DIR}/.progress

BUILD_TYPE=$3

function prepare_dirs
{
	if [ ! -e $OPENSOURCE_WORK_DIR ]; then
		mkdir -p $OPENSOURCE_WORK_DIR
	fi

	if [ ! -e $OPENSOURCE_PROGRESS_DIR ]; then
		mkdir -p $OPENSOURCE_PROGRESS_DIR
	fi
}

function clean_modules
{
	for i in $MODULES; do
		if [ -e $OPENSOURCE_WORK_DIR/$i ]; then
			cd $OPENSOURCE_WORK_DIR/$i
			if [ -f Makefile ]; then
				echo "Cleaning Module [$i]..."
				make clean
			fi
		else
			echo "Module [$i] Does not Exist. Nothing to clean"
		fi
	done

	if [ -e $OPENSOURCE_WORK_DIR ]; then
		cd $OPENSOURCE_WORK_DIR
		if [ -d .progress ]; then
			cd .progress
			find -name .made | xargs rm -f 
			find -name .installed | xargs rm -f
		fi
	fi
}

function clobber_modules
{
	rm -Rf $OPENSOURCE_WORK_DIR
}

function handle_http_download
{
	WGET_ARGS="-t 2 -T 10 $1 -O $2"
	if [ x"$HTTP_PROXY" == "x" ]; then
		echo "wget $WGET_ARGS"
		wget $WGET_ARGS 
	else
		echo "http_proxy=$HTTP_PROXY wget $WGET_ARGS"
		http_proxy=$HTTP_PROXY wget $WGET_ARGS
	fi
}

function apply_patches
{
	local PATCHES_DIR="$CCSP_ROOT_DIR/utilities/opensource/patches/$1"

	if [ ! -d $PATCHES_DIR ]; then
		echo "Module [$1]. No Patches to Apply"
		return
	fi

	for i in `ls $PATCHES_DIR`
	do
		echo "Module: [$1]. Applying Patch $PATCHES_DIR/$i"
		patch -p1 < $PATCHES_DIR/$i
	done
}

function handle_dbus
{
	local DBUS_NAME="dbus"
	local DBUS_VERSION="1.4.14"
	local DBUS_PACKAGE_NAME="$DBUS_NAME-$DBUS_VERSION.tar.gz"
	local DBUS_URI="http://dbus.freedesktop.org/releases/dbus/$DBUS_PACKAGE_NAME"
	local DBUS_WORK_DIR=$OPENSOURCE_WORK_DIR/$DBUS_NAME
	local DBUS_PROGRESS_DIR=$OPENSOURCE_PROGRESS_DIR/.$DBUS_NAME

	if [ $build_dbus -eq 0 ]; then decorate_log "[$DBUS_NAME] BUILD IS OFF"; return; fi

	cd $OPENSOURCE_WORK_DIR

	if [ ! -e $DBUS_PROGRESS_DIR ]; then mkdir $DBUS_PROGRESS_DIR; fi
	if [ ! -e $DBUS_PROGRESS_DIR/.download ]; then 
		decorate_log "[$DBUS_NAME] Handling Download..."
		handle_http_download $DBUS_URI $DBUS_PACKAGE_NAME && touch $DBUS_PROGRESS_DIR/.download
	fi

	if [ ! -e $DBUS_PROGRESS_DIR/.extract ]; then
		decorate_log "[$DBUS_NAME] Handling Extract..."
		tar xvzf $DBUS_PACKAGE_NAME && cd $DBUS_NAME-$DBUS_VERSION && touch $DBUS_PROGRESS_DIR/.extract
	else
		cd $DBUS_NAME-$DBUS_VERSION
	fi

	if [ ! -e $DBUS_PROGRESS_DIR/.patched ]; then
		decorate_log "[$DBUS_NAME] Handling Patching..."
		apply_patches $DBUS_NAME ; touch $DBUS_PROGRESS_DIR/.patched
	fi

	if [ ! -e $DBUS_PROGRESS_DIR/.configured ]; then
		decorate_log "[$DBUS_NAME] Handling Configure..."
		decorate_log "[$DBUS_NAME]->configure->[$DBUS_CONFIGURE]"
       	CFLAGS="${CFLAGS_ARG}" LDFLAGS="${LDFLAGS_ARG}"  \
		./configure $DBUS_CONFIGURE ; touch $DBUS_PROGRESS_DIR/.configured
	fi

	if [ ! -e $DBUS_PROGRESS_DIR/.made ]; then
		decorate_log "[$DBUS_NAME] Handling Make..."
		make ; touch $DBUS_PROGRESS_DIR/.made
	fi

	if [ ! -e $DBUS_PROGRESS_DIR/.installed ]; then
		decorate_log "[$DBUS_NAME] Handling Install..."
		make install ; touch $DBUS_PROGRESS_DIR/.installed
	fi

	cd $CCSP_ROOT_DIR
}

function handle_snmp
{
	local SNMP_NAME="net-snmp"
	local SNMP_VERSION="5.7.1"
	local SNMP_PACKAGE_NAME="$SNMP_NAME-$SNMP_VERSION.tar.gz"
	local SNMP_URI="http://downloads.sourceforge.net/$SNMP_NAME/$SNMP_PACKAGE_NAME"
	local SNMP_WORK_DIR=$OPENSOURCE_WORK_DIR/$SNMP_NAME
	local SNMP_PROGRESS_DIR=$OPENSOURCE_PROGRESS_DIR/.$SNMP_NAME

	if [ $build_snmp -eq 0 ]; then decorate_log "[$SNMP_NAME] BUILD IS OFF"; return; fi

	cd $OPENSOURCE_WORK_DIR

	if [ ! -e $SNMP_PROGRESS_DIR ]; then mkdir $SNMP_PROGRESS_DIR; fi
	if [ ! -e $SNMP_PROGRESS_DIR/.download ]; then 
		decorate_log "[$SNMP_NAME] Handling Download..."
		handle_http_download $SNMP_URI $SNMP_PACKAGE_NAME && touch $SNMP_PROGRESS_DIR/.download
	fi

	if [ ! -e $SNMP_PROGRESS_DIR/.extract ]; then
		decorate_log "[$SNMP_NAME] Handling Extract..."
		tar xvzf $SNMP_PACKAGE_NAME && cd $SNMP_NAME-$SNMP_VERSION && touch $SNMP_PROGRESS_DIR/.extract
	else
		cd $SNMP_NAME-$SNMP_VERSION
	fi

	if [ ! -e $SNMP_PROGRESS_DIR/.patched ]; then
		decorate_log "[$SNMP_NAME] Handling Patching..."
		apply_patches $SNMP_NAME ; touch $SNMP_PROGRESS_DIR/.patched
	fi

	if [ ! -e $SNMP_PROGRESS_DIR/.configured ]; then
		decorate_log "[$SNMP_NAME] Handling Configure..."
		decorate_log "[$SNMP_NAME]->configure->[$SNMP_CONFIGURE]"
		echo -e "\n\n\n\n\n\n" | \
        	CPPFLAGS="${CFLAGS_ARG}" CFLAGS="${CFLAGS_ARG}" LDFLAGS="${LDFLAGS_ARG}"  \
			./configure $SNMP_CONFIGURE ; touch $SNMP_PROGRESS_DIR/.configured
	fi

	if [ ! -e $SNMP_PROGRESS_DIR/.made ]; then
		decorate_log "[$SNMP_NAME] Handling Make..."
		make ; touch $SNMP_PROGRESS_DIR/.made
	fi

	if [ ! -e $SNMP_PROGRESS_DIR/.installed ]; then
		decorate_log "[$SNMP_NAME] Handling Install..."
		make install ; touch $SNMP_PROGRESS_DIR/.installed
	fi

	cd $CCSP_ROOT_DIR
}

function handle_openssl
{
    local OPENSSL_NAME="openssl"
    local OPENSSL_VERSION="0.9.8l"
    local OPENSSL_PACKAGE_NAME="$OPENSSL_NAME-$OPENSSL_VERSION.tar.gz"
    local OPENSSL_URI="http://www.openssl.org/source/$OPENSSL_PACKAGE_NAME"
    local OPENSSL_WORK_DIR=$OPENSOURCE_WORK_DIR/$OPENSSL_NAME
	local OPENSSL_PROGRESS_DIR=$OPENSOURCE_PROGRESS_DIR/.$OPENSSL_NAME

	if [ $build_openssl -eq 0 ]; then decorate_log "[$OPENSSL_NAME] BUILD IS OFF"; return; fi

	cd $OPENSOURCE_WORK_DIR

	if [ ! -e $OPENSSL_PROGRESS_DIR ]; then mkdir $OPENSSL_PROGRESS_DIR; fi
	if [ ! -e $OPENSSL_PROGRESS_DIR/.download ]; then 
		decorate_log "[$OPENSSL_NAME] Handling Download..."
		handle_http_download $OPENSSL_URI $OPENSSL_PACKAGE_NAME && touch $OPENSSL_PROGRESS_DIR/.download
	fi

	if [ ! -e $OPENSSL_PROGRESS_DIR/.extract ]; then
		decorate_log "[$OPENSSL_NAME] Handling Extract..."
		tar xvzf $OPENSSL_PACKAGE_NAME && cd $OPENSSL_NAME-$OPENSSL_VERSION && touch $OPENSSL_PROGRESS_DIR/.extract
	else
		cd $OPENSSL_NAME-$OPENSSL_VERSION
	fi

	if [ ! -e $OPENSSL_PROGRESS_DIR/.patched ]; then
		decorate_log "[$OPENSSL_NAME] Handling Patching..."
		apply_patches $OPENSSL_NAME ; touch $OPENSSL_PROGRESS_DIR/.patched
	fi

	if [ ! -e $OPENSSL_PROGRESS_DIR/.configured ]; then
		decorate_log "[$OPENSSL_NAME] Handling Configure..."
		decorate_log "[$OPENSSL_NAME]->configure->[$OPENSSL_CONFIGURE]"
        CFLAGS="${CFLAGS_ARG}" LDFLAGS="${LDFLAGS_ARG}"  \
			./Configure $OPENSSL_CONFIGURE ; touch $OPENSSL_PROGRESS_DIR/.configured
	fi

	if [ ! -e $OPENSSL_PROGRESS_DIR/.made ]; then
		decorate_log "[$OPENSSL_NAME] Handling Make..."
		make depend ; make CC=${CROSS_COMPILE}gcc AR="${CROSS_COMPILE}ar r" RANLIB="${CROSS_COMPILE}ranlib" \
				; touch $OPENSSL_PROGRESS_DIR/.made
	fi

	if [ ! -e $OPENSSL_PROGRESS_DIR/.installed ]; then
		decorate_log "[$OPENSSL_NAME] Handling Install..."
		make install ; touch $OPENSSL_PROGRESS_DIR/.installed
	fi

	cd $CCSP_ROOT_DIR
}

function handle_curl
{
    local CURL_NAME="curl"
    local CURL_VERSION="7.28.1"
    local CURL_PACKAGE_NAME="$CURL_NAME-$CURL_VERSION.tar.bz2"
    local CURL_URI="http://curl.haxx.se/download/$CURL_PACKAGE_NAME"
    local CURL_WORK_DIR=$OPENSOURCE_WORK_DIR/$CURL_NAME
	local CURL_PROGRESS_DIR=$OPENSOURCE_PROGRESS_DIR/.$CURL_NAME

	if [ $build_curl -eq 0 ]; then decorate_log "[$CURL_NAME] BUILD IS OFF"; return; fi

	cd $OPENSOURCE_WORK_DIR

	if [ ! -e $CURL_PROGRESS_DIR ]; then mkdir $CURL_PROGRESS_DIR; fi
	if [ ! -e $CURL_PROGRESS_DIR/.download ]; then 
		decorate_log "[$CURL_NAME] Handling Download..."
		handle_http_download $CURL_URI $CURL_PACKAGE_NAME && touch $CURL_PROGRESS_DIR/.download
	fi

	if [ ! -e $CURL_PROGRESS_DIR/.extract ]; then
		decorate_log "[$CURL_NAME] Handling Extract..."
		tar xvjf $CURL_PACKAGE_NAME && cd $CURL_NAME-$CURL_VERSION && touch $CURL_PROGRESS_DIR/.extract
	else
		cd $CURL_NAME-$CURL_VERSION
	fi

	if [ ! -e $CURL_PROGRESS_DIR/.patched ]; then
		decorate_log "[$CURL_NAME] Handling Patching..."
		apply_patches $CURL_NAME ; touch $CURL_PROGRESS_DIR/.patched
	fi

	if [ ! -e $CURL_PROGRESS_DIR/.configured ]; then
		decorate_log "[$CURL_NAME] Handling Configure..."
		decorate_log "[$CURL_NAME]->configure->[$CURL_CONFIGURE]"
       	CFLAGS="${CFLAGS_ARG}" LDFLAGS="${LDFLAGS_ARG}"  \
        ./configure $CURL_CONFIGURE ; touch $CURL_PROGRESS_DIR/.configured
	fi

	if [ ! -e $CURL_PROGRESS_DIR/.made ]; then
		decorate_log "[$CURL_NAME] Handling Make..."
		make ; touch $CURL_PROGRESS_DIR/.made
	fi

	if [ ! -e $CURL_PROGRESS_DIR/.installed ]; then
		decorate_log "[$CURL_NAME] Handling Install..."
		make install ; touch $CURL_PROGRESS_DIR/.installed
	fi

	cd $CCSP_ROOT_DIR
}

function handle_fcgi
{
    local FCGI_NAME="fcgi"
    local FCGI_VERSION="2.4.0"
    local FCGI_PACKAGE_NAME="$FCGI_NAME-$FCGI_VERSION.tar.gz"
    local FCGI_URI="http://fossies.org/linux/www/$FCGI_PACKAGE_NAME"
    local FCGI_WORK_DIR=$OPENSOURCE_WORK_DIR/$FCGI_NAME
	local FCGI_PROGRESS_DIR=$OPENSOURCE_PROGRESS_DIR/.$FCGI_NAME

	if [ $build_fcgi -eq 0 ]; then decorate_log "[$FCGI_NAME] BUILD IS OFF"; return; fi

	cd $OPENSOURCE_WORK_DIR

	if [ ! -e $FCGI_PROGRESS_DIR ]; then mkdir $FCGI_PROGRESS_DIR; fi
	if [ ! -e $FCGI_PROGRESS_DIR/.download ]; then 
		decorate_log "[$FCGI_NAME] Handling Download..."
		handle_http_download $FCGI_URI $FCGI_PACKAGE_NAME && touch $FCGI_PROGRESS_DIR/.download
	fi

	if [ ! -e $FCGI_PROGRESS_DIR/.extract ]; then
		decorate_log "[$FCGI_NAME] Handling Extract..."
		tar xvzf $FCGI_PACKAGE_NAME && cd $FCGI_NAME-$FCGI_VERSION && touch $FCGI_PROGRESS_DIR/.extract
	else
		cd $FCGI_NAME-$FCGI_VERSION
	fi

	if [ ! -e $FCGI_PROGRESS_DIR/.patched ]; then
		decorate_log "[$FCGI_NAME] Handling Patching..."
		apply_patches $FCGI_NAME ; touch $FCGI_PROGRESS_DIR/.patched
	fi

	if [ ! -e $FCGI_PROGRESS_DIR/.configured ]; then
		decorate_log "[$FCGI_NAME] Handling Configure..."
		decorate_log "[$FCGI_NAME]->configure->[$FCGI_CONFIGURE]"
       	CFLAGS="${CFLAGS_ARG}" LDFLAGS="${LDFLAGS_ARG}"  \
        ./configure $FCGI_CONFIGURE ; touch $FCGI_PROGRESS_DIR/.configured
	fi

	if [ ! -e $FCGI_PROGRESS_DIR/.made ]; then
		decorate_log "[$FCGI_NAME] Handling Make..."
		make ; touch $FCGI_PROGRESS_DIR/.made
	fi

	if [ ! -e $FCGI_PROGRESS_DIR/.installed ]; then
		decorate_log "[$FCGI_NAME] Handling Install..."
		make install ; touch $FCGI_PROGRESS_DIR/.installed
	fi

	cd $CCSP_ROOT_DIR
}

function handle_upnp
{
    local UPNP_NAME="libupnp"
    local UPNP_VERSION="1.6.18"
    local UPNP_PACKAGE_NAME="$UPNP_NAME-$UPNP_VERSION.tar.bz2"
	local UPNP_URI="http://downloads.sourceforge.net/pupnp/$UPNP_PACKAGE_NAME"
    local UPNP_WORK_DIR=$OPENSOURCE_WORK_DIR/$UPNP_NAME
	local UPNP_PROGRESS_DIR=$OPENSOURCE_PROGRESS_DIR/.$UPNP_NAME

	if [ $build_upnp -eq 0 ]; then decorate_log "[$UPNP_NAME] BUILD IS OFF"; return; fi

	cd $OPENSOURCE_WORK_DIR

	if [ ! -e $UPNP_PROGRESS_DIR ]; then mkdir $UPNP_PROGRESS_DIR; fi
	if [ ! -e $UPNP_PROGRESS_DIR/.download ]; then 
		decorate_log "[$UPNP_NAME] Handling Download..."
		handle_http_download $UPNP_URI $UPNP_PACKAGE_NAME && touch $UPNP_PROGRESS_DIR/.download
	fi

	if [ ! -e $UPNP_PROGRESS_DIR/.extract ]; then
		decorate_log "[$UPNP_NAME] Handling Extract..."
		tar xvjf $UPNP_PACKAGE_NAME && cd $UPNP_NAME-$UPNP_VERSION && touch $UPNP_PROGRESS_DIR/.extract
	else
		cd $UPNP_NAME-$UPNP_VERSION
	fi

	if [ ! -e $UPNP_PROGRESS_DIR/.patched ]; then
		decorate_log "[$UPNP_NAME] Handling Patching..."
		apply_patches $UPNP_NAME ; touch $UPNP_PROGRESS_DIR/.patched
	fi

	if [ ! -e $UPNP_PROGRESS_DIR/.configured ]; then
		decorate_log "[$UPNP_NAME] Handling Configure..."
		decorate_log "[$UPNP_NAME]->configure->[$UPNP_CONFIGURE]"
       	CFLAGS="${CFLAGS_ARG}" LDFLAGS="${LDFLAGS_ARG}"  \
        ./configure $UPNP_CONFIGURE ; touch $UPNP_PROGRESS_DIR/.configured
	fi

	if [ ! -e $UPNP_PROGRESS_DIR/.made ]; then
		decorate_log "[$UPNP_NAME] Handling Make..."
		make ; touch $UPNP_PROGRESS_DIR/.made
	fi

	if [ ! -e $UPNP_PROGRESS_DIR/.installed ]; then
		decorate_log "[$UPNP_NAME] Handling Install..."
		make install ; touch $UPNP_PROGRESS_DIR/.installed
	fi

	cd $CCSP_ROOT_DIR
}

function handle_zlib
{
    local ZLIB_NAME="zlib"
    local ZLIB_VERSION="1.2.5"
    local ZLIB_PACKAGE_NAME="$ZLIB_NAME-$ZLIB_VERSION.tar.gz"
	local ZLIB_URI="http://prdownloads.sourceforge.net/libpng/$ZLIB_PACKAGE_NAME"
    local ZLIB_WORK_DIR=$OPENSOURCE_WORK_DIR/$ZLIB_NAME
	local ZLIB_PROGRESS_DIR=$OPENSOURCE_PROGRESS_DIR/.$ZLIB_NAME

	if [ $build_zlib -eq 0 ]; then decorate_log "[$ZLIB_NAME] BUILD IS OFF"; return; fi

	cd $OPENSOURCE_WORK_DIR

	if [ ! -e $ZLIB_PROGRESS_DIR ]; then mkdir $ZLIB_PROGRESS_DIR; fi
	if [ ! -e $ZLIB_PROGRESS_DIR/.download ]; then 
		decorate_log "[$ZLIB_NAME] Handling Download..."
		handle_http_download $ZLIB_URI $ZLIB_PACKAGE_NAME && touch $ZLIB_PROGRESS_DIR/.download
	fi

	if [ ! -e $ZLIB_PROGRESS_DIR/.extract ]; then
		decorate_log "[$ZLIB_NAME] Handling Extract..."
		tar xvf $ZLIB_PACKAGE_NAME && cd $ZLIB_NAME-$ZLIB_VERSION && touch $ZLIB_PROGRESS_DIR/.extract
	else
		cd $ZLIB_NAME-$ZLIB_VERSION
	fi

	if [ ! -e $ZLIB_PROGRESS_DIR/.patched ]; then
		decorate_log "[$ZLIB_NAME] Handling Patching..."
		apply_patches $ZLIB_NAME ; touch $ZLIB_PROGRESS_DIR/.patched
	fi

	if [ ! -e $ZLIB_PROGRESS_DIR/.configured ]; then
		decorate_log "[$ZLIB_NAME] Handling Configure..."
		decorate_log "[$ZLIB_NAME]->configure->[$ZLIB_CONFIGURE]"
       	CHOST=${HOST} CFLAGS="${CFLAGS_ARG}" LDFLAGS="${LDFLAGS_ARG}"  \
        ./configure $ZLIB_CONFIGURE ; touch $ZLIB_PROGRESS_DIR/.configured
	fi

	if [ ! -e $ZLIB_PROGRESS_DIR/.made ]; then
		decorate_log "[$ZLIB_NAME] Handling Make..."
		make ; touch $ZLIB_PROGRESS_DIR/.made
	fi

	if [ ! -e $ZLIB_PROGRESS_DIR/.installed ]; then
		decorate_log "[$ZLIB_NAME] Handling Install..."
		make install ; touch $ZLIB_PROGRESS_DIR/.installed
	fi

	cd $CCSP_ROOT_DIR
}

function handle_headers_copy
{
	# Please note that this is a temporary scheme. The Headers of opensource packages
    #  should be referred to by standard Install Directory
	local PACKAGES="uuid"
	local OPENSOURCE_HDR_DIR=$CCSP_ROOT_DIR/ExtDependency/opensource/
	cd $OPENSOURCE_HDR_DIR
	for dir1 in $PACKAGES; do
		if [ -d $PREFIX_DIR/include/$dir1 ]; then
			decorate_log "[$PREFIX_DIR/include/$dir1] Already Exists. Not Copying..."
		else
			decorate_log "Copying $dir1 to $PREFIX_DIR/include"
			mkdir -p $PREFIX_DIR/include
			cp -r $dir1 $PREFIX_DIR/include
		fi
	done
	cd $CCSP_ROOT_DIR
}

function final_install
{
	local bin_list=""
	local sbin_list=""
	local lib_list=""
	local mibs_list="share/snmp/mibs/*.txt"

	if [ $build_dbus -eq 1 ]; then 
		bin_list="$bin_list dbus-daemon"
		lib_list="$lib_list libdbus-1.so* libdbus-1*"
	fi

	if [ $build_snmp -eq 1 ]; then 
		sbin_list="$sbin_list snmpd"
		lib_list="$lib_list libnetsnmp*.so*"
	fi

	if [ $build_openssl -eq 1 ]; then
		lib_list="$lib_list libssl* libcrypto*"
	fi

	if [ $build_curl -eq 1 ]; then
		lib_list="$lib_list libcurl.so*"
	fi

	if [ $build_fcgi -eq 1 ]; then
		lib_list="$lib_list libfcgi.a*"
	fi

	if [ $build_upnp -eq 1 ]; then
		lib_list="$lib_list libupnp.so* libixml.so* libthreadutil.so*"
	fi

	if [ $build_zlib -eq 1 ]; then
		lib_list="$lib_list libz*"
	fi

	cd $CCSP_OPENSOURCE_DIR

	for b in $bin_list; do
		echo "Copying Binary: [$b->$CCSP_OUT_DIR/]"
		cp -fp bin/$b $CCSP_OUT_DIR/
	done

	for s_bin in $sbin_list; do
		echo "Copying Binary: [$s_bin->$CCSP_OUT_DIR/]"
		cp -fp sbin/$s_bin $CCSP_OUT_DIR/
	done

	mkdir -p $CCSP_OUT_DIR/lib
	for l in $lib_list; do
		echo "Copying Library: [$l->$CCSP_OUT_DIR/]"
		cp -fp lib/$l $CCSP_OUT_DIR/lib
	done

	if [ $build_snmp -eq 1 ]; then 
		mkdir -p $CCSP_OUT_DIR/mibs
		echo "Copying MIBS: [$$mibs_list->$CCSP_OUT_DIR/mibs]"
		cp -fp $mibs_list $CCSP_OUT_DIR/mibs
	fi

	cd $CCSP_ROOT_DIR
	
}

function build_modules
{
	prepare_dirs
	handle_headers_copy
	handle_dbus
	handle_openssl
	handle_snmp
	handle_curl
	handle_fcgi
	handle_upnp
	handle_zlib

	final_install
	
}

# Actual Work Starts here
case $BUILD_TYPE in
"clean")
	clean_modules
	# For clean, build should follow the clean process
	build_modules
	echo "Open Source clean+Build Done!!!";;
"clobber")
	clobber_modules
	echo "Open Source Purge Done!!!";;
"build")
	build_modules
	echo "Open Source Build Done!!!";;
"*")
	echo "Invalid Argument [$BUILD_TYPE]. Only build|clean|clobber are allowed";
esac
