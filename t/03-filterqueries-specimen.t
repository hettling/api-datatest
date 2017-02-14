#!/usr/bin/perl
use warnings;

BEGIN {
	our @plan = $ENV{'TEST_SPEC'} ? 'no_plan' : 'skip_all' => 'env var TEST_DWCA not set';
}

use Test::More @plan;
use LWP::Simple;
use JSON;
use JSON::Path;
use Data::Dumper;

use GoogleIO;

#my $sheet_url = "https://docs.google.com/spreadsheets/d/16QBK3J9kK9gBJKpZ61s1BRvMJ7ONpPy_JzM9m67GfsM";
#$sheet_url .= "/pub?output=tsv";

my $token = 'google_spreadsheet.session';
my $gio = GoogleIO->new( 'token' => $token  );
my $spreadsheet = 'FilterQueries-specimen';
my $worksheet = 'Sheet1';

my $apiversion = "v2";
my $test = "http://145.136.242.170:8080";
my $dev = "http://145.136.242.164:8080";

my @rows = $gio->get_worksheet_rows( $spreadsheet, $worksheet );
print Dumper(\@rows);

# Get number of rows, should be the same for each column!
##my $nrow = scalar @{ $table{ (sort keys %table)[0] } };

# The table has several named columns which map to the indexed search fields.
# Exception is assertions, against which the query is tested. Assertion
# columns have the prefix 'assertion.'. Below we check from the column
# names which ones are assertions and which ones are search fields

# Each row is a test case for which a query is build,
# thus we iterate over each row, build the query and test 
# the assertions given in the table. 


for my $row_idx ( 0..$#rows ) {
	my $row = $rows[$row_idx];		
		
	my %table = %$row;
	my @assertions = grep { /^assertion\..+$/ } keys( %table );
	my @fields = grep { ! /^assertion\..+$/ } keys( %table );

	# build the query
	my $query = "/specimen/query/?";
	
	# get fields that do not have empty values
	for my $f ( @fields ) {		
		if ( my $val = $table{$f} ) {
			$query .= "$f=$val&";
		}
	}

	# only true if all test were ok!
	my $all_ok = 1;		
	my $error = "";
	
	# iterate over different testing environments
	for my $ip ( ($test) ) {
				
		my $base_url = $ip . "/" . $apiversion;
		my $url = $base_url . $query;
		print $url . "\n";
		# Make query to server
		my $ua = LWP::UserAgent->new;
		print "Sending request for query $url\n";
		my $response = $ua->get( $url );
		my $test = ok( $response->is_success, "Succesful response code" );				
		my $json_response = $response->decoded_content;
		
		$all_ok &&= $test;		
		# add to error string if not succesful
		$error .= $json_response . "\n" if ! $test;
		
		# Now test for the assertions.
		for ( @assertions ) {			
			my $assert = $_;
			# get value for assertion
			my $assert_val = $table{$assert};
			# remove 'assertion.' prefix
			$assert =~ s/^assertion\.//g;
			ok( $assert_val, "Assertion value present for $assert: $assert_val");
			my $jp = JSON::Path->new( "\$.$assert" );
			my $response_val = $jp->value( $json_response );
			$test = ok( $assert_val eq $response_val, "Response value $response_val is equal to assertion value $assert_val" );
			$all_ok &&= $test;		
			# add to error string if not succesful
			$error .=  "Failed test: Response value $response_val is equal to assertion value $assert_val\n" if ! $test;			
		}
	}
	my $result = $all_ok ? "OK" : "FAIL";
	$gio->set_result( $spreadsheet, $worksheet, $row_idx+2, "result", $result ); # Caution: offset
	$gio->set_result( $spreadsheet, $worksheet, $row_idx+2, "error", $error ); # Caution: offset
	
}
