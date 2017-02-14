#! /usr/bin/perl

# This script checks for a google spreadsheet and if it was updates, it
# triggers a script

use GoogleIO;
use Data::Dumper;
use File::Compare;

my $token = 'google_spreadsheet.session';
my $trigger_script = './script/travis-trigger.sh';
my $gio = GoogleIO->new( 'token' => $token  );

my $spreadsheet = 'tests-phase2';
my @worksheets = qw( filter search metadata data aggregation static-download dynamic-download );

my $worksheet = $worksheets[0];

# get cached worksheet
my $cached_sheet = "cache-${spreadsheet}-${worksheet}.tsv";

# write current worksheet to tsv
my $current_sheet = "current-sheet.tsv";
$gio->write_sheet_tsv( $spreadsheet, $worksheet, $current_sheet );

# write output to logfile
open my $fh, '>>', "listener.log" or die $!;

# Compare contents of cached and current file
if ( compare( $cached_sheet, $current_sheet) == 0 ) {
	print $fh "Cached file $cached_sheet and current file $current_sheet equal, no action taken \n";
} 
else {
	print $fh "Remote spreadsheet was updated, executing trigger $trigger_script \n";
	system( "sh $trigger_script" );
	print $fh "Triggered travis webhook\n";
}

# make the current file the cache file
$gio->write_sheet_tsv( $spreadsheet, $worksheet, $cached_sheet );
unlink( $current_sheet );





