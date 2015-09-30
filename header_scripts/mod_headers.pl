##########################################################################
# If not stated otherwise in this file or this component's Licenses.txt
# file the following copyright and licenses apply:
#
# Copyright 2015 RDK Management
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##########################################################################
#!/usr/bin/perl

use Switch;
use File::Copy;
use strict;
use warnings;

sub print_usage()
{
    print "Usage: \n";
    print "    $0 --help\n";
    print "      Provides the information on how to use this script\n";
    print "    $0 <listfile> <type>\n";
    print "      <listfile>: The file that containes the list of all the\n";
    print "          source and header files.\n";
    print "      <type>\n";
    print "          xml: Adds Comment specific to XML Files (<!-- />)\n";
    print "          sh: Adds Comment specific to Script Files (#)\n";
    print "          make: Adds Comment specific to Script Files (#)\n";
    print "          c: Adds Comment specific to C Code (/* ... */)\n";
	print " ************************************************************** \n";
	print " The License Headers will be places at appropriate location.\n";
	print " c/h: will be placed at the beginning of the file.\n";
	print " xml: will be placed as a comment just after the <?xml?> tag\n";
	print " makefiles: will be places at the beginning of the file.\n";
	print " sh: will be placed just after the binary indicator (#!) line\n";
	print " ************************************************************** \n";
    exit;

}

my $c_header = <<'END_MESSAGE';
/**********************************************************************
   Copyright [2014] [Cisco Systems, Inc.]
 
   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at
 
       http://www.apache.org/licenses/LICENSE-2.0
 
   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
**********************************************************************/
END_MESSAGE

my $sh_header = <<'END_MESSAGE';
#######################################################################
#   Copyright [2014] [Cisco Systems, Inc.]
# 
#   Licensed under the Apache License, Version 2.0 (the \"License\");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
# 
#       http://www.apache.org/licenses/LICENSE-2.0
# 
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an \"AS IS\" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#######################################################################
END_MESSAGE

my $xml_header = <<'END_MESSAGE';
<!--
   Copyright [2014] [Cisco Systems, Inc.]

   Licensed under the Apache License, Version 2.0 (the \"License\");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an \"AS IS\" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
-->
END_MESSAGE

my $file_list_name = shift or print_usage();
my $file_type = shift or print_usage();
my $debug_flag = 1;
my $tmp_file_name = "/tmp/temp_conv_file";

sub debug
{
	print shift unless !$debug_flag;
}

sub debug_op
{
	print shift unless $debug_flag;
}

sub trim
{
	my $s = shift;
	$s =~ s/^\s+|\s+$//g unless ($s eq ""); 
	return $s;
}

sub check_if_header_present
{
	my $file = shift;
	my $match_count = 0;
	open (FILE, $file) or die "Failed to Open file $file\n";
	while (<FILE>) {
		if ($_ =~ m/(Cisco Systems, Inc\.)/) {
			$match_count++;
		} elsif ($_ =~ m/(Licensed under the Apache License, Version 2\.0)/) {
			$match_count++;
		} elsif ($_ =~ m/(WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND)/) {
			$match_count++;
		}
	}

	close (FILE);

	if ($match_count == 3) {
		return 1;
	} else {
		return 0;
	}
}

sub add_header() {
	open (FILE_LIST, $file_list_name) or
		die "Failed to open Configuration file $file_list_name\n";

	foreach(<FILE_LIST>) {
		my $file_name = trim($_);
		my $hdr_added = 0;
		if ($file_name eq "") {
			next;
		}

		debug "Handling File $file_name...";

		if (check_if_header_present($file_name)) {
			debug "[Already Present]\n";
			next;
		}

		open (ONE_FILE, $file_name) or die "Failed to Open file $file_name\n";
		open (NEW_FILE, '>', $tmp_file_name) or die "Failed to Open file $tmp_file_name\n";
	
		if ($file_type eq "sh") {
			my $first_line = <ONE_FILE>;
			if ($first_line =~ m/^\#\!/) {
				print NEW_FILE $first_line;
				print NEW_FILE "\n" . $sh_header . "\n";
			} else {
				print NEW_FILE $sh_header . "\n";
				print NEW_FILE $first_line;
			}
			$hdr_added = 1;
		} elsif ($file_type eq "make") {
			print NEW_FILE $sh_header . "\n";
			$hdr_added = 1;
		} elsif ($file_type eq "c") {
			print NEW_FILE $c_header . "\n";
			$hdr_added = 1;
		} elsif ($file_type eq "xml") {
			my $line = "";
			while (!$hdr_added && ($line = <ONE_FILE>)) {
				print NEW_FILE $line;
				if ((trim($line) ne "") && ($line =~ m/\<\?xml/) && ($line =~ m/\?\>/)) {
					print NEW_FILE "\n" . $xml_header . "\n";
					$hdr_added = 1;
				}
			}
		}

		foreach (<ONE_FILE>) {
			print NEW_FILE $_;
		}

		close(NEW_FILE);
		close(ONE_FILE);

		unlink $file_name;
		#rename $tmp_file_name, $file_name;
		move($tmp_file_name, $file_name);

		if ($hdr_added) {
			debug "[Added]\n";
		} else {
			debug "[Ignored]\n";
		}
	}

	close(FILE_LIST);
}

switch ($file_type) {
	case "sh" 			{ print "Handling Script Files\n"; }
	case "make" 		{ print "Handling Makefiles\n"; }
	case "c" 			{ print "Handling C/H Files\n"; }
	case "xml" 			{ print "Handling XML Files\n" }
	else 				{ die "File type [$file_type] not supported\n"}
}

add_header();

