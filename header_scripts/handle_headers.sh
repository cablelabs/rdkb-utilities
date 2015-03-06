#!/bin/sh


utilities/header_scripts/find_files.sh

utilities/header_scripts/mod_headers.pl /tmp/source_filelist c
utilities/header_scripts/mod_headers.pl /tmp/makefile_filelist make
utilities/header_scripts/mod_headers.pl /tmp/script_filelist sh
utilities/header_scripts/mod_headers.pl /tmp/xml_filelist xml

