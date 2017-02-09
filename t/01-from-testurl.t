# This test case evaluates simple API calls. Input data is given
# in a google sheet
# INPUT :
#  - query URL(s)
# TESTS : 
#  - result JSON against baseline JSON
#  - md5 of result JSON against baseline  

#!/usr/bin/perl
use strict;
use warnings;
use Test::More 'no_plan';

use LWP::Simple;
use JSON;
use Digest::MD5 'md5_hex';
use Data::Dumper;

use GoogleIO;

my $ua = LWP::UserAgent->new;
my $token = 'google_spreadsheet.session';
my $gio = GoogleIO->new( 'token' => $token  );

my $spreadsheet = 'tests-phase2';
my @worksheets = qw( filter search metadata data aggregation static-download dynamic-download );
@worksheets = ( 'filter' );

for my $worksheet ( @worksheets ) {		

	my @rows = $gio->get_worksheet_rows( $spreadsheet, $worksheet );	
	# print Dumper(\@rows);

	for my $row_idx ( 0..$#rows ) {
		my $r = $rows[$row_idx];		
		my $test_nr = $r->{'testno'};
			
		## only true if all test were ok!
		my $all_ok = 1;		
		my $response = $ua->get( $r->{'testurl'} );

		my $test = ok( $response->is_success, "Test : '$worksheet', number: $test_nr:  Response code ok" );
		$all_ok &&= $test;
		
		my $json_response = $response->decoded_content;
		##print $json_response . "\n";

		# Comparisons to baseline
		# md5sum response, if given
		if ( my $baseline_md5 = $r->{'baseline_md5'} ) {
			my $md5 = md5_hex( $json_response );
			$test = ok ( $md5 eq $baseline_md5, "Test : '$worksheet', number: $test_nr: Response md5 matches baseline md5" );
			print $md5 . "\n";
			$all_ok &&= $test;
		}
		# compare json response string, if given
		if ( my $baseline_json = $r->{'baseline_json'} ) {
			$test = ok ( $json_response eq $baseline_json, "Test : '$worksheet', number: $test_nr: Response json matches baseline json" );
			$all_ok &&= $test;
		}
		# compare json response to response given in URL
		if ( my $baseline_url = $r->{'baseline_url'} ) {
			my $baseline_json = $ua->get( $baseline_url )->decoded_content;
			$test = ok ( $json_response eq $baseline_json, "Test : '$worksheet', number: $test_nr: Response of test and baseline URLs match" );						
			$all_ok &&= $test;
		}
		my $result = $all_ok ? "OK" : "FAIL";
		$gio->set_result( $spreadsheet, $worksheet, $row_idx+2, $result ); # Caution: offset
	}	

}

