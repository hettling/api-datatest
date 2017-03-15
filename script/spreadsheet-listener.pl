#! /usr/bin/perl

# This script checks for a google spreadsheet and if it was updates, it
# triggers a script.
# Running on some server, you might want to run this script with cron, you can do this
# by adding something like below to your crontab:
# * * * * * cd /path/to/api-datatest && /usr/bin/perl script/spreadsheet-listener.pl 2>&1

use GoogleIO;
use Data::Dumper;

my $token = 'google_spreadsheet.session';
my $trigger_script = './script/trigger.sh';

my $gio = GoogleIO->new( 'token' => $token  );

my $spreadsheet = 'tests-phase2';

# Check following worksheets if changes occured
my @worksheets = qw( filter search metadata data aggregation static-download dynamic-download );

# write output to logfile
open my $fh, '>>', "listener.log" or die $!;

# print date and time to logfile
print $fh localtime . " BEGIN $0 called \n";

for my $worksheet ( @worksheets ) {

	# Compare contents of cached and current file
	if ( ! $gio->is_updated( $spreadsheet, $worksheet ) ) {
		print $fh localtime() . " No changes in $spreadsheet $worksheet, no action taken \n";
	} 
	else {		
		print $fh localtime() . " Remote worksheet '$worksheet' was updated, executing trigger $trigger_script \n";
		# Export environment variable from which the trigger will get the worksheet name to process
		$ENV{'API_TESTTOOL_T1'} = $worksheet;
		print $fh localtime  . " Setting API_TESTTOOL_T1=$worksheet \n";
		my $ret = system( "sh $trigger_script" ) and die $!;
		print $fh localtime() . " Trigger script $trigger_script called, return value: $ret \n";
	}
}

print $fh localtime  . " DONE $0 \n";
close $fh;

