#!/bin/sh
#
# Utility tools for building configure/packages by AntPickax
#
# Copyright 2018 Yahoo Japan Corporation.
#
# AntPickax provides utility tools for supporting autotools
# builds.
#
# These tools retrieve the necessary information from the
# repository and appropriately set the setting values of
# configure, Makefile, spec,etc file and so on.
# These tools were recreated to reduce the number of fixes and
# reduce the workload of developers when there is a change in
# the project configuration.
# 
# For the full copyright and license information, please view
# the license file that was distributed with this source code.
#
# AUTHOR:   Takeshi Nakatani
# CREATE:   Fri, Apr 13 2018
# REVISION:
#

#
# Autobuid for debian package
#
func_usage()
{
	echo ""
	echo "Usage:  $1 [-buildnum <build number>] [-nodebuild] [-rootdir] [-product <product name>] [-class <class name>] [-disttype <os/version>] [-y] [additional debuild options]"
	echo "        -buildnum                     specify build number for packaging(default 1)"
	echo "        -nodebuild                    stops before do debuild command."
	echo "        -rootdir                      layout \"debian\" directory for packaging under source top directory"
	echo "        -product                      specify product name(use PACKAGE_NAME in Makefile s default)"
	echo "        -class                        specify package class name(optional)"
	echo "        -disttype                     specify \"OS/version name\", ex: ubuntu/trusty"
	echo "        -y                            runs no interactive mode."
	echo "        additional debuild options    this script run debuild with \"-uc -us\", can specify additional options."
	echo "        -h                            print help"
	echo ""
}

func_get_default_class()
{
	dh_make -h 2>/dev/null | grep '\--multi' >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo "multi"
	else
		echo "library"
	fi
}

PRGNAME=`basename $0`
MYSCRIPTDIR=`dirname $0`
MYSCRIPTDIR=`cd ${MYSCRIPTDIR}; pwd`
SRCTOP=`cd ${MYSCRIPTDIR}/..; pwd`
BUILDDEBDIR=${SRCTOP}/debian_build

#
# Check options
#
IS_DEBUILD=1
IS_INTERACTIVE=1
IS_ROOTDIR=0
DH_MAKE_AUTORUN_OPTION=""
BUILD_NUMBER=1
IS_OS_UBUNTU=0
OS_VERSION_NAME=
DEBUILD_OPT=""
PKGCLASSNAME=`func_get_default_class`
while [ $# -ne 0 ]; do
	if [ "X$1" = "X" ]; then
		break

	elif [ "X$1" = "X-h" -o "X$1" = "X-help" ]; then
		func_usage $PRGNAME
		exit 0

	elif [ "X$1" = "X-buildnum" ]; then
		shift
		if [ $# -eq 0 ]; then
			echo "ERROR: -buildnum option needs parameter." 1>&2
			exit 1
		fi
		BUILD_NUMBER=$1

	elif [ "X$1" = "X-nodebuild" ]; then
		IS_DEBUILD=0
		BUILD_NUMBER=

	elif [ "X$1" = "X-rootdir" ]; then
		IS_ROOTDIR=1

	elif [ "X$1" = "X-product" ]; then
		shift
		if [ $# -eq 0 ]; then
			echo "ERROR: -product option needs parameter." 1>&2
			exit 1
		fi
		PACKAGE_NAME=$1

	elif [ "X$1" = "X-class" ]; then
		shift
		if [ $# -eq 0 ]; then
			echo "ERROR: -class option needs parameter." 1>&2
			exit 1
		fi
		PKGCLASSNAME=$1

	elif [ "X$1" = "X-disttype" ]; then
		shift
		if [ $# -eq 0 ]; then
			echo "ERROR: -disttype option needs parameter." 1>&2
			exit 1
		fi
		OS_VERSION_NAME=$1
		echo ${OS_VERSION_NAME} | grep -i 'ubuntu' >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			IS_OS_UBUNTU=1
			OS_VERSION_NAME=`echo ${OS_VERSION_NAME} | sed 's#[Uu][Bb][Uu][Nn][Tt][Uu]/##g'`

		else
			echo ${OS_VERSION_NAME} | grep -i 'debian' >/dev/null 2>&1
			if [ $? -ne 0 ]; then
				echo "ERROR: -disttype option parameter must be ubuntu or debian." 1>&2
				exit 1
			fi
			IS_OS_UBUNTU=0
			OS_VERSION_NAME=`echo ${OS_VERSION_NAME} | sed 's#[Dd][Ee][Bb][Ii][Aa][Nn]/##g'`
		fi

	elif [ "X$1" = "X-y" ]; then
		IS_INTERACTIVE=0
		DH_MAKE_AUTORUN_OPTION="-y"

	else
		if [ "X${DEBUILD_OPT}" != "X" ]; then
			DEBUILD_OPT="${DEBUILD_OPT} $1"
		else
			DEBUILD_OPT="$1"
		fi
	fi
	shift
done

#
# Package name
#
if [ "X${PACKAGE_NAME}" = "X" ]; then
	PACKAGE_NAME=`grep "^PACKAGE_NAME" ${SRCTOP}/Makefile 2>/dev/null | awk '{print $3}' 2>/dev/null`
	if [ "X${PACKAGE_NAME}" = "X" ]; then
		echo "ERROR: no product name" 1>&2
		exit 1
	fi
fi

#
# Welcome message and confirming for interactive mode
#
if [ ${IS_INTERACTIVE} -eq 1 ]; then
	echo "---------------------------------------------------------------"
	echo " Do you change these file and commit to github?"
	echo " - ChangeLog              modify / add changes like dch tool format"
	echo " - Git TAG                stamp git tag for release"
	echo "---------------------------------------------------------------"
	while true; do
		echo -n "Confirm: [y/n] "
		read CONFIRM

		if [ "X${CONFIRM}" = "XY" -o "X${CONFIRM}" = "Xy" ]; then
			break;
		elif [ "X${CONFIRM}" = "XN" -o "X${CONFIRM}" = "Xn" ]; then
			echo "Bye..."
			exit 1
		fi
	done
	echo ""
fi

#
# Make dist package by make dist
#
${SRCTOP}/autogen.sh				|| exit 1
${SRCTOP}/configure ${CONFIGUREOPT}	|| exit 1
PACKAGE_VERSION=`${MYSCRIPTDIR}/make_variables.sh --pkg_version`
PACKAGE_MAJOR_VER=`${MYSCRIPTDIR}/make_variables.sh --major_number`

echo "===== make dist: start =============================="
make dist || exit 1
echo "===== make dist: end   =============================="

#
# Create debian package directory and change current
#
echo "===== prepare working directory: start ============="

if [ -f ${BUILDDEBDIR} ]; then
	echo "ERROR: debian file exists, could not make debian directory." 1>&2
	exit 1
fi
if [ -d ${BUILDDEBDIR} ]; then
	echo "WANING: debian directory exists, remove and remake it." 1>&2
	rm -rf ${BUILDDEBDIR} || exit 1
fi
mkdir ${BUILDDEBDIR}	|| exit 1
cd ${BUILDDEBDIR}		|| exit 1

#
# copy dist package and expand source files
#
cp ${SRCTOP}/${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.gz .	|| exit 1
tar xvfz ${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.gz			|| exit 1

#
# change current directory
#
EXPANDDIR=${BUILDDEBDIR}/${PACKAGE_NAME}-${PACKAGE_VERSION}
cd ${EXPANDDIR} || exit 1

#
# initialize debian directory
#
if [ "X${LOGNAME}" = "X" -a "X${USER}" = "X" ]; then
	# [NOTE]
	# if run in docker container, Neither LOGNAME nor USER may be set in the environment variables.
	# dh_make needs one of these environments.
	#
	export USER="root"
	export LOGNAME="root"
fi
dh_make -f ${BUILDDEBDIR}/${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.gz --createorig --${PKGCLASSNAME} ${DH_MAKE_AUTORUN_OPTION} || exit 1

#
# remove unnecessary template files
#
rm -rf ${EXPANDDIR}/debian/*.ex ${EXPANDDIR}/debian/*.EX ${EXPANDDIR}/debian/${PACKAGE_NAME}-doc.* ${EXPANDDIR}/debian/README.* ${EXPANDDIR}/debian/docs ${EXPANDDIR}/debian/*.install

#
# adding some lines into rules file
#
mv ${EXPANDDIR}/debian/rules ${EXPANDDIR}/debian/rules.base
head -1 ${EXPANDDIR}/debian/rules.base																							> ${EXPANDDIR}/debian/rules  || exit 1
sed '/^#/d' ${EXPANDDIR}/debian/rules.base | sed '/^$/{N; /^\n$/D;}' | sed 's/autotools-dev/autotools-dev,systemd/'				>> ${EXPANDDIR}/debian/rules || exit 1
echo ""																															>> ${EXPANDDIR}/debian/rules || exit 1
echo "# for ${PACKAGE_NAME} package"																							>> ${EXPANDDIR}/debian/rules || exit 1
echo "# Setup systemd.timer for old debhelper"																					>> ${EXPANDDIR}/debian/rules || exit 1
echo "override_dh_auto_install:"																								>> ${EXPANDDIR}/debian/rules || exit 1
echo "	dh_auto_install --destdir=debian/${PACKAGE_NAME}"																		>> ${EXPANDDIR}/debian/rules || exit 1
echo "	install -D -m 644 debian/k2hr3-get-resource.timer debian/${PACKAGE_NAME}/lib/systemd/system/k2hr3-get-resource.timer"	>> ${EXPANDDIR}/debian/rules || exit 1
echo ""																															>> ${EXPANDDIR}/debian/rules || exit 1
echo "# Not enable by installing."																								>> ${EXPANDDIR}/debian/rules || exit 1
echo "# And only handle systemd.timer."																							>> ${EXPANDDIR}/debian/rules || exit 1
echo "override_dh_systemd_enable:"																								>> ${EXPANDDIR}/debian/rules || exit 1
echo "	dh_systemd_enable"																										>> ${EXPANDDIR}/debian/rules || exit 1
echo "	if [ -f debian/${PACKAGE_NAME}.preinst.debhelper ]; then	rm -f debian/${PACKAGE_NAME}.preinst.debhelper;		fi"		>> ${EXPANDDIR}/debian/rules || exit 1
echo "	if [ -f debian/${PACKAGE_NAME}.postinst.debhelper ]; then	rm -f debian/${PACKAGE_NAME}.postinst.debhelper;	fi"		>> ${EXPANDDIR}/debian/rules || exit 1
echo "	if [ -f debian/${PACKAGE_NAME}.prerm.debhelper ]; then		cat debian/${PACKAGE_NAME}.prerm.debhelper | (rm debian/${PACKAGE_NAME}.prerm.debhelper; sed 's/k2hr3-get-resource.service//g' > debian/${PACKAGE_NAME}.prerm.debhelper)	fi"	>> ${EXPANDDIR}/debian/rules || exit 1
echo "	if [ -f debian/${PACKAGE_NAME}.postrm.debhelper ]; then		cat debian/${PACKAGE_NAME}.postrm.debhelper | (rm debian/${PACKAGE_NAME}.postrm.debhelper; sed 's/k2hr3-get-resource.service//g' > debian/${PACKAGE_NAME}.postrm.debhelper)	fi"	>> ${EXPANDDIR}/debian/rules || exit 1
echo ""																															>> ${EXPANDDIR}/debian/rules || exit 1
echo "# Not support init.d"																										>> ${EXPANDDIR}/debian/rules || exit 1
echo "override_dh_installinit:"																									>> ${EXPANDDIR}/debian/rules || exit 1
echo "	echo 'Not enable init'"																									>> ${EXPANDDIR}/debian/rules || exit 1
echo ""																															>> ${EXPANDDIR}/debian/rules || exit 1
echo "# Not start by installing."																								>> ${EXPANDDIR}/debian/rules || exit 1
echo "# And only handle systemd.timer."																							>> ${EXPANDDIR}/debian/rules || exit 1
echo "override_dh_systemd_start:"																								>> ${EXPANDDIR}/debian/rules || exit 1
echo "	dh_systemd_start"																										>> ${EXPANDDIR}/debian/rules || exit 1
echo "	if [ -f debian/${PACKAGE_NAME}.preinst.debhelper ]; then	rm -f debian/${PACKAGE_NAME}.preinst.debhelper;		fi"		>> ${EXPANDDIR}/debian/rules || exit 1
echo "	if [ -f debian/${PACKAGE_NAME}.postinst.debhelper ]; then	rm -f debian/${PACKAGE_NAME}.postinst.debhelper;	fi"		>> ${EXPANDDIR}/debian/rules || exit 1
echo "	if [ -f debian/${PACKAGE_NAME}.prerm.debhelper ]; then		cat debian/${PACKAGE_NAME}.prerm.debhelper | (rm debian/${PACKAGE_NAME}.prerm.debhelper; sed 's/k2hr3-get-resource.service//g' > debian/${PACKAGE_NAME}.prerm.debhelper)	fi"	>> ${EXPANDDIR}/debian/rules || exit 1
echo "	if [ -f debian/${PACKAGE_NAME}.postrm.debhelper ]; then		cat debian/${PACKAGE_NAME}.postrm.debhelper | (rm debian/${PACKAGE_NAME}.postrm.debhelper; sed 's/k2hr3-get-resource.service//g' > debian/${PACKAGE_NAME}.postrm.debhelper)	fi"	>> ${EXPANDDIR}/debian/rules || exit 1

if [ "X${CONFIGUREOPT}" != "X" ]; then
	echo ""																														>> ${EXPANDDIR}/debian/rules || exit 1
	echo "override_dh_auto_configure:"																							>> ${EXPANDDIR}/debian/rules || exit 1
	echo "	dh_auto_configure -- ${CONFIGUREOPT}"																				>> ${EXPANDDIR}/debian/rules || exit 1
fi

rm ${EXPANDDIR}/debian/rules.base

#
# files for systemd service
#
cp src/k2hr3-get-resource.timer   ${EXPANDDIR}/debian/k2hr3-get-resource.timer   || exit 1
cp src/k2hr3-get-resource.service ${EXPANDDIR}/debian/k2hr3-get-resource.service || exit 1
echo "src/k2hr3-get-resource-helper usr/libexec"		>> ${EXPANDDIR}/debian/${PACKAGE_NAME}.install || exit
echo "src/k2hr3-get-resource-helper.conf etc/antpickax"	>> ${EXPANDDIR}/debian/${PACKAGE_NAME}.install || exit

#
# copy copyright
#
cp ${MYSCRIPTDIR}/copyright ${EXPANDDIR}/debian/copyright || exit 1

#
# copy control file
#
cp ${MYSCRIPTDIR}/control ${EXPANDDIR}/debian/control || exit 1

#
# copy changelog with converting build number
#
CHLOG_ORG_MENT=`cat ChangeLog | grep "^ --" | head -1`
CHLOG_NEW_MENT=`cat ${EXPANDDIR}/debian/changelog | grep "^ --" | head -1`
if [ "X${BUILD_NUMBER}" = "X" ]; then
	if [ ${IS_OS_UBUNTU} -eq 1 ]; then
		cat ChangeLog | sed "s/${CHLOG_ORG_MENT}/${CHLOG_NEW_MENT}/g" | sed "s/ trusty;/ ${OS_VERSION_NAME};/g" > ${EXPANDDIR}/debian/changelog || exit 1
	else
		cat ChangeLog | sed "s/${CHLOG_ORG_MENT}/${CHLOG_NEW_MENT}/g" | sed 's/ trusty;/ unstable;/g' > ${EXPANDDIR}/debian/changelog || exit 1
	fi
else
	if [ ${IS_OS_UBUNTU} -eq 1 ]; then
		cat ChangeLog | sed "s/${PACKAGE_VERSION}/${PACKAGE_VERSION}-${BUILD_NUMBER}/g" | sed "s/${CHLOG_ORG_MENT}/${CHLOG_NEW_MENT}/g" | sed "s/ trusty;/ ${OS_VERSION_NAME};/g" > ${EXPANDDIR}/debian/changelog || exit 1
	else
		cat ChangeLog | sed "s/${PACKAGE_VERSION}/${PACKAGE_VERSION}-${BUILD_NUMBER}/g" | sed "s/${CHLOG_ORG_MENT}/${CHLOG_NEW_MENT}/g" | sed 's/ trusty;/ unstable;/g' > ${EXPANDDIR}/debian/changelog || exit 1
	fi
fi
if [ ! -f ${EXPANDDIR}/debian/compat ]; then
	echo "9" > ${EXPANDDIR}/debian/compat
fi

echo "===== prepare working directory: end ==============="

#
# change debian directory to source top directory
#
if [ ${IS_ROOTDIR} -eq 1 ]; then
	if [ -f ${SRCTOP}/debian ]; then
		echo "ERROR: ${SRCTOP}/debian file exists, could not make debian directory." 1>&2
		exit 1
	fi
	if [ -d ${SRCTOP}/debian ]; then
		echo "${SRCTOP}/debian directory exists, remove and remake it..." 1>&2
		rm -rf ${SRCTOP}/debian || exit 1
	fi
	cp -rp ${EXPANDDIR}/debian ${SRCTOP}/. || exit 1

	#
	# change current directory
	#
	cd ${SRCTOP}

	#
	# base directory is changed
	#
	BUILDDEBDIR=${SRCTOP}
fi

#
# Check stop before debuild(for manually)
#
if [ ${IS_DEBUILD} -ne 1 ]; then
	#
	# Not run debuild (this means just stop preparing the file)
	#
	echo "MESSAGE: ${PRGNAME} exits immediately before debuild is executed,"
	echo "         that is, it prepares only files and directories."
	echo "         By running \"debuild -uc -us(-tc -b)\", you can create"
	echo "         the debian package manually and find the created package"
	echo "         in \"${BUILDDEBDIR}/..\" directory."
	echo ""

	exit 0
fi

#
# Run debuild
#
echo "===== build package: start ========================="
debuild -us -uc || exit 1
echo "===== build package: end ==========================="

#
# Check and show debian package
#
ls ${BUILDDEBDIR}/${PACKAGE_NAME}_${PACKAGE_VERSION}-${BUILD_NUMBER}*.deb >/dev/null 2>&1
if [ $? -eq 0 ]; then
	echo "===== show ${BUILDDEBDIR}/${PACKAGE_NAME}_${PACKAGE_VERSION}-${BUILD_NUMBER}*.deb package: start ====="
	dpkg -c ${BUILDDEBDIR}/${PACKAGE_NAME}_${PACKAGE_VERSION}-${BUILD_NUMBER}*.deb
	echo ""
	dpkg -I ${BUILDDEBDIR}/${PACKAGE_NAME}_${PACKAGE_VERSION}-${BUILD_NUMBER}*.deb
	echo "===== show ${BUILDDEBDIR}/${PACKAGE_NAME}_${PACKAGE_VERSION}-${BUILD_NUMBER}*.deb package: end ====="
fi

#
# finish
#
echo ""
echo "You can find ${PACKAGE_NAME} ${PACKAGE_VERSION}-${BUILD_NUMBER} version debian package in ${BUILDDEBDIR} directory."
echo ""
exit 0

#
# Local variables:
# tab-width: 4
# c-basic-offset: 4
# End:
# vim600: noexpandtab sw=4 ts=4 fdm=marker
# vim<600: noexpandtab sw=4 ts=4
#
