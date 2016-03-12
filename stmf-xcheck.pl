#!/usr/bin/perl

#
# Name		: stmf-xcheck.pl
# Author	: Jason.Banham@nexenta.com
# Date		: 26th - 29th February 2016
# Usage		: stmf-xcheck.pl <manifest.xml>
# Purpose	: Check for duplicate views/mappings in XML data
# Version	: 0.03
# Legal         : Copyright 2016, Nexenta Systems, Inc. 
# History	: 0.01 - Initial version
#		  0.02 - Extract the value of the clashing key and print it
#		  0.03 - Added basic help option
#

#
# The input file is an XML manifest of the svc:/system/stmf service gathered using:
#
# svccfg export -a svc:/system/stmf > stmf-manifest.xml
#
# Once obtained we need to parse the data, looking for duplicate views, so it helps
# to understand the format of the input file.
# Typically we'll see this:
#
# - a property group for view entry 0
# - a property group for the LU associated with view entry 0
# - zero or more property group entries for that LU
#
# for example:
#
#    <property_group name='view_entry-0-600144F0DEA04F000000544E6DF40004' type='application'>
#      <propval name='all_hosts' type='boolean' value='false'/>
#      <propval name='all_targets' type='boolean' value='false'/>
#      <propval name='host_group' type='ustring' value='va1-p00e00vsph0003'/>
#      <propval name='lu_nbr' type='opaque' value='0004000000000000'/>
#      <propval name='target_group' type='ustring' value='FC_Only'/>
#    </property_group>
#    <property_group name='lu-600144F0DEA04F000000544E6DF40004' type='application'>
#      <propval name='ve_cnt' type='count' value='6'/>
#      <property name='view_entry-0-600144F0DEA04F000000544E6DF40004' type='ustring'/>
#      <property name='view_entry-1-600144F0DEA04F000000544E6DF40004' type='ustring'/>
#    </property_group>
#    <property_group name='view_entry-1-600144F0DEA04F000000544E6DF40004' type='application'>
#      <propval name='all_hosts' type='boolean' value='false'/>
#      <propval name='all_targets' type='boolean' value='false'/>
#      <propval name='host_group' type='ustring' value='va1-p00e00vsph0008'/>
#      <propval name='lu_nbr' type='opaque' value='0004000000000000'/>
#      <propval name='target_group' type='ustring' value='FC_Only'/>
#    </property_group>
#
# As we're primarily interested in the views, we can safely ignore the lu-XXXX entry and
# concentrate on just the view_entry-XXXX data when searching the file.  We can extract
# the LU from the view entry name itself as the last component.
#

use strict;
use Getopt::Std;

#
# Show how to run the program, if no arguments/file supplied
#
sub usage{
    print "Usage: stmf-xcheck.pl stmf-manifest.xml\n";
}
 

#
# Show the help page
#
sub help{
    usage();
    printf("\nThis program scans the manifest for the svc:/system/stmf service to look for duplicate views.\n");
    printf("It expects an XML file that has been generated, thus:\n\n");
    printf("bash# svccfg export -a svc:/system/stmf > /tmp/stmf-manifest.xml\n\n");
    printf("If duplicate views are found, you'll get a list consisting of the LU, the HG and TG, with a list of clashing views.\n");
    printf("Example:\n");
    printf("  600144F0DEA04F000000544E94060027:va1-p00e00vsph0000:FC_Only - view entry 8 clashes with entry 7\n\n");
    printf("\n\nNOTE:\n-----\n");
    printf("Although we may find view entry 7 clashes with say 8, this is typically because 8 appears\n");
    printf("first in the manifest and this is usually a sign of something going wrong, having been added\n");
    printf("whilst STMF is an unknown state.\n");
    printf("You may also see views 0 - 7 clashing, because views 8 - 14 appear first in the manifest.\n");
    printf("If in doubt, check the active node (where possible) and see which views are really in use.\n");
    printf("You'll likely find it's the higher views that are actually the duplicates!\n");
}


#
# Scan for arguments and process accordingly
#

# declare the perl command line flags/options we want to allow
my %options=();
getopts("h", \%options);

if (defined $options{h}) {
    help();
    exit;
}


#
# Check we've actually supplied an XML file for parsing
#
my $num_args = $#ARGV + 1;
if ( $num_args < 1 ) {
    print "Usage: stmf-xcheck.pl stmf-manifest.xml\n";
    exit;
}


#
# Open the file and pull it into a large array
#
open (my $file, "<", $ARGV[0]) || die "Can't read file: $ARGV[0]";
my (@stmf_list) = <$file>;
close($file);

chomp(@stmf_list);
my ($stmf_lines) = scalar @stmf_list;
my $index = 0;
my $clashing_viewcount = 0;


#
# Walk through the XML data, searching for the property group view_entry lines only.
# When we find an entry, extract the lu and view number, then move on to the HG and TG
# lines in the data.
#
# As we're using an associative array we can use the LU, TG and HG (minus the view number)
# as a unique index into the array, storing the view number as the value.
# If we used the view number as part of the searchable key, nothing would ever clash.
# 
# Once we've constructed the viewline, push that string as a key into the array with the
# view number as the value.
#
# Finally all we now need to do is check if the value exists in the array - if not, push
# the value, otherwise we've found a clash.
#

my %lookup_table;

printf("Searching for duplicate views in manifest\n");
printf("If any duplicates are found, they will appear as - LU : HG : TG\n\n");

while ($index < $stmf_lines) {
    if ( $stmf_list[$index] =~ /property_group name='view_entry/ ) {
	my ($guf, $view) = split /'/, $stmf_list[$index];
	my @view_array = split /-/, $view;
	my $view_num = $view_array[1];
	my $lu = $view_array[2];
	$index += 3;
	my ($guf, $hg) = split /value='/, $stmf_list[$index];
	my ($hg, $guf) = split /'/, $hg;
	$index++;
	my ($guf, $lu_nbr) = split /value='/, $stmf_list[$index];
	my ($lu_nbr, $guf) = split /'/, $lu_nbr;
	$index++;
	my ($guf, $tg) = split /value='/, $stmf_list[$index];
	my ($tg, $guf) = split /'/, $tg;

	my $viewline = $lu . ":" . $hg . ":" . $tg;
	if (exists $lookup_table{$viewline}) {
	    $clashing_viewcount++;
	    my $existing_view = $lookup_table{$viewline};
	    printf("%s - view entry %s clashes with entry %s\n", $viewline, @$existing_view, $view_num);
        }
    	else {
	    push( @{ $lookup_table { $viewline } }, $view_num);
	}
    }
    $index++;
}

if ( $clashing_viewcount == 0 ) {
    printf("No clashing views found.\n");
}

printf("\n");
