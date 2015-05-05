#!/bin/bash

#set -x 

SOURCE_FILELIST="/tmp/source_filelist"
MAKEFILE_FILELIST="/tmp/makefile_filelist"
SCRIPT_FILELIST="/tmp/script_filelist"
XML_FILELIST="/tmp/xml_filelist"
ALL_OTHER_FILELIST="/tmp/all_other_filelist"
WARN_FILELIST="/tmp/warn_filelist"

function check_and_log
{
	# Check if Header already Exists
	CHECK1=`grep -m 1 -n "Cisco Systems, Inc." $1 | cut -f1 -d:`
	CHECK2=`grep -m 1 -n "Licensed under the Apache License, Version 2.0" $1 | cut -f1 -d:`
	CHECK3=`grep -m 1 -n "WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND" $1 | cut -f1 -d:`

	if [ x"$CHECK1" == "x" ] || [ x"$CHECK2" == "x" ] || [ x"$CHECK3" == "x" ]; then
		echo "$each_file to $2"
		echo "$each_file" >> $2
	elif [ $CHECK1 -ge $CHECK2 ] || [ $CHECK1 -ge $CHECK3 ] || [ $CHECK2 -ge $CHECK3 ]; then
		echo "$each_file to $WARN_FILELIST"
		echo "$each_file" >> $WARN_FILELIST
	fi
}

SOURCE_PATTERN="*.c *.h *.cpp *.hs"
MAKEFILE_PATTERN="Makefile makefile *.mk"
SCRIPT_PATTERN="ccsp_build"
XML_PATTERN="*.xml"
ALL_KNOWN_PATTERNS="$SOURCE_PATTERN $MAKEFILE_PATTERN $SCRIPT_PATTERN $XML_PATTERN"

# Source Files
echo "" > $SOURCE_FILELIST
for pat in $SOURCE_PATTERN; do
	for each_file in `find . -type f -iname "$pat"`; do
		check_and_log $each_file $SOURCE_FILELIST
	done
done

# Makefiles
echo "" > $MAKEFILE_FILELIST
for pat in $MAKEFILE_PATTERN; do
	for each_file in `find . -type f -iname "$pat"`; do
		check_and_log $each_file $MAKEFILE_FILELIST
	done
done

# Script Files
echo "" > $SCRIPT_FILELIST
# for *.sh only since can not put it in "pat"
for each_file in `find . -type f -iname '*.sh'`; do
	check_and_log $each_file $SCRIPT_FILELIST
done

for pat in $SCRIPT_PATTERN; do
	for each_file in `find . -type f -iname "$pat"`; do
		check_and_log $each_file $SCRIPT_FILELIST
	done
done

# XML Files
echo "" > $XML_FILELIST
for pat in $XML_PATTERN; do
	for each_file in `find . -type f -iname "$pat"`; do
		check_and_log $each_file $XML_FILELIST
	done
done

# All others
# ################## TODO #######################################
# This one is Buggy. Needs fixing
# ###############################################################
#find_cmd="find . -type f -iname \"*\""
#for pat in $ALL_KNOWN_PATTERNS; do
#    find_cmd="$find_cmd -and -not -iname \"$pat\""
#done

