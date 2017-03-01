#!/usr/bin/perl
use warnings;

BEGIN {
	our @plan = $ENV{'API_TESTTOOL_T1'} ? 'no_plan' : 'skip_all' => 'env var API_TESTTOOL_T1 not set';
}

use Test::More @plan;
use LWP::Simple;
use JSON;
use JSON::Path;
use Digest::MD5 'md5_hex';
use File::Temp qw(tempfile tempdir);
use Data::Dumper;

use GoogleIO;

# This test case evaluates simple API calls. Input data is given
# in a google sheet
# INPUT :
#  - query URL(s)
# TESTS : 
#  - result JSON against baseline JSON
#  - md5 of result JSON against baseline  

my $ua = LWP::UserAgent->new;
my $token = 'google_spreadsheet.session';
my $gio = GoogleIO->new( 'token' => $token  );

# Caution: hard-coded spreadsheet name
my $spreadsheet = 'tests-phase2';
my $worksheet = $ENV{'API_TESTTOOL_T1'};



my @rows = $gio->get_worksheet_rows( $spreadsheet, $worksheet );	

for my $row_idx ( 0..$#rows ) {
	my $r = $rows[$row_idx];		
	my $test_nr = $r->{'testno'};
	
	my $all_ok = 1; # only true if all test were ok!
	my $error = "";	# errorstring to be returned to spreadsheet
	my $repeats =  $r->{'repeats'} ||  0;
  REP: for my $rep ( 1..$repeats ) {
	  
	  my $teststr = "Test : '$worksheet', tesno: $test_nr, repeat $rep:";		  			
	  my $response = $ua->get( $r->{'test_url'} );		  
	  my $response_str = $response->decoded_content;
	  ## print $response->status_line . "\n";
	  # serialize response to see if it is a zip
	  my $response_file = _save_response( $response_str );
	  my $is_archive = _is_zipped( $response_file );
	  my $test = ok( $response->is_success,  "$teststr Response code ok" );
	  
	  # add to error string if not succesful
	  $error .= $response_str . "\n" if ! $test;		  
	  $all_ok &&= $test;
	  
	  if ( grep {$_ eq 'response_code'} keys(%$r) ) {
		  $gio->set_result( $spreadsheet, $worksheet, $row_idx+2, "response_code", $response->status_line );
	  }
	  next REP if ! $test;
	  
	  # send json reponse to google spreadsheet, if column exists
	  if ( grep {$_ eq 'response_json'} keys(%$r) ) {
			  $gio->set_result( $spreadsheet, $worksheet, $row_idx+2, "response_json", $response_str );
	  }
	  # Comparisons to baseline
	  # Get md5 sum and compare to baseline, if presen
	  my $md5 = md5_hex( $response_str );
	  $gio->set_result( $spreadsheet, $worksheet, $row_idx+2, "response_md5", $md5 );
	  if ( my $baseline_md5 = $r->{'baseline_md5'} ) {
		  $test = ok ( $md5 eq $baseline_md5, "$teststr Response md5 matches baseline md5" );
		  $all_ok &&= $test;
		  $error .= "Response md5 $md5 did not match baseline md5 $baseline_md5\n" if ! $test;
		  }
	  # Compare to baseline JSON, if present
	  if ( my $baseline_json = $r->{'baseline_json'} ) {
		  $test = ok ( $response_str eq $baseline_json, "$teststr Response json matches baseline json" );
		  $all_ok &&= $test;
		  $error .= "Response json did not match baseline json\n" if ! $test;
	  }
	  # Compare to baseline URL, if present
	  if ( my $baseline_url = $r->{'baseline_url'} ) {			 
		  my $baseline_response = $ua->get( $baseline_url )->decoded_content;
		  if ( $is_archive ) {
			  # Compare responses of two
			  my $baseline_response_file = _save_response( $baseline_response );
			  $test = ok ( _zip_equal( $response_file, $baseline_response_file ), "Archive files of baseline and response match");
			  $all_ok &&= $test;
			  $error .= "Archive files for baseline and response URL differ" if ! $test;
		  }
		  else {
			  $test = ok ( $response_str eq $baseline_response, "$teststr Response of test and baseline URLs match" );						
			  $all_ok &&= $test;
				  $error .= "Response json did not match response from baseline url $baseline_url \n" if ! $test;
		  }
	  }
	  # Get total size and compare to baseline, if present		  
	  if ( grep {$_ eq 'response_total_size'} keys (%$r) ) {
		  my $jp = JSON::Path->new( "\$.totalSize" );
		  my $response_total_size = $jp->value( $response_str );
		  $gio->set_result( $spreadsheet, $worksheet, $row_idx+2, "response_total_size", $response_total_size );
		  if ( my $baseline_total_size = $r->{'baseline_total_size'} ) {		
			  $test = ok ( $response_total_size == $baseline_total_size, "$teststr total size $response_total_size == $baseline_total_size");
			  $all_ok &&= $test;
			  $error .= "Reponse total size $response_total_size does not match baseline total size $baseline_total_size \n" if ! $test;				  
		  }
	  }
	  # Test if we need to validate a darwin core archive
	  if ( grep {$_ eq 'response_validation_result'} keys(%$r) ) {
		  $test = ok ( $is_archive, "Reponse is zipped archive" );			  			  
		  $all_ok &&= $test;
		  $error .= "Reponse is not a zip archive \n" if ! $test;
		  my $is_valid = _validate_dwca( $response_file );
		  $test = ok ( $is_valid, "Response is a valid Darwin core archive" );
		  $all_ok &&= $test;
		  $error .= "Reponse not a valid Darwin core archive" if ! $test;
		  $gio->set_result( $spreadsheet, $worksheet, $row_idx+2, "response_validation_result", $is_valid ? "OK" : "FAIL" );
	  }
	  next REP if ! $all_ok;
  }
	my $result = $all_ok ? 'OK' : 'FAIL';
	$result = 'SKIPPED' if ! $r->{'repeats'};
	$gio->set_result( $spreadsheet, $worksheet, $row_idx+2, "overall_test_result", $result ); # Caution: offset
	$gio->set_result( $spreadsheet, $worksheet, $row_idx+2, "reported_error", $error ); # Caution: offset
}	



# save response to file
sub _save_response {
	my $response = shift;
	
	my ($fh, $filename) = tempfile( CLEANUP => 0 );
	print $fh $response;
	close $fh;
	
	return $filename;
}

# check if a given file is a zip archive
sub _is_zipped {
	my $filename = shift;
	
	# use 'file' command to get type of file
	my $filetype = `file $filename` or die $!;
	# test for string "Zip archive data" in file command output
	my $zipped = $filetype =~ /Zip archive data/;

	return $zipped;
}

# test if two zip archives are equal
sub _zip_equal {
	my ( $file1, $file2 ) = @_;
	
	my $diff = `zdiff $file1 $file2`;
	# test for string 'differ'
	my $equal = ! $diff  =~ /differ/;
	
	return ( $diff );
}

# use dwca-validator (https://github.com/gbif/dwca-validator)
# to validate a zipped response containing a darwin core archive
sub _validate_dwca {
	my $filename = shift;
	my $is_valid = 0;

	# this string is in output when file is valid
	my $correct_output = "The Dwc-A file looks valid according to current validation chain\.";
	my $output = `dwca-validator -s ${filename} 2>&1`;
	if ( $output =~ /$correct_output/ ) {
		$is_valid = 1;
	}
	
	return $is_valid;				
}
