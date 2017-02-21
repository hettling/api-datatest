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
# For the DWCA tests on two sheets, we will need a different test
my @dwca_sheets = qw( static-download dynamic-download );

# write output to logfile
open my $fh, '>>', "listener.log" or die $!;

my %sheets = ('tests-phase2'=>'filter', 'FilterQueries-specimen'=>'Sheet1');

for my $k ( keys(%sheets) ) {
	my $spreadsheet = $k;
	my $worksheet = $sheets{$k};
	
	# Compare contents of cached and current file
	if ( is_updated( $gio, $spreadsheet, $worksheet ) ) {
		print $fh "Cached file and current file $current_sheet equal, no action taken \n";
	} 
	else {
		if ( $spreadsheet eq "FilterQueries-specimen" ) {
			$ENV{'TEST_SPEC'}=1;
		}
		
		print $fh "Remote spreadsheet was updated, executing trigger $trigger_script \n";
		system( "sh $trigger_script" );
		print $fh "Trigger script called\n";
	}
}
