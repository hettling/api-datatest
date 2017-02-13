#!/usr/bin/perl
use strict;
use warnings;

BEGIN {
	our @plan = $ENV{'TEST_DWCA'} ? 'no_plan' : 'skip_all' => 'env var TEST_DWCA not set';
}


use Test::More @plan;

use LWP::Simple;
use JSON;
use JSON::Path;
use File::Temp qw(tempfile);

use Data::Dumper;

##http:/api.biodiversitydata.nl/v0/specimen/search/dwca/?collection=mammalia

# Get Spreadsheet data
# my $sheet_url = "https://docs.google.com/spreadsheets/d/1Fb2tvVBU8-YTNAgklAPNV9iiiy2ZQSqQfZkhrJ0A1sQ";
# $sheet_url .= "/pub?output=tsv";

my $apiversion = "v2";
my @types = qw( taxon ); ## qw( taxon specimen );

my $test_dashboard = "http://145.136.242.166";
my $test = "http://145.136.242.170";
my $dev = "http://145.136.242.164";
# my $url = "http://api.biodiversitydata.nl/v0/specimen/search/dwca/?collection=$c";

my $base_url = $test . ":8080/$apiversion/";

# Get all collections
my $datafile = 't/testdata/collections.tsv';
my %table = _read_data( $datafile );
my @collections = @{ $table{'collection'} };

for my $type ( @types ) {
	for my $c ( @collections ) {
		ok ( $c, "Testing dwca download for $type in collection $c" );
		
		# my $query = $base_url . "$type/dwca/query/?collection=$c"; 
		# my $query = "http://api.biodiversitydata.nl/v0/specimen/search/dwca/?collection=$c";
		my $query = $base_url . "$type/dwca/dataset/$c"; 
		
		print "Executing query $query \n";
		
		# make API request to donwload zip content
		my $can_accept = HTTP::Message::decodable;
		my $response = LWP::UserAgent->new->get( $query, 'Accept-Encoding' => $can_accept );

		# check status
		if ( ok ( $response->is_success, "Checking HTTP status" ) ) {
			
			# write zip response to file
			my ($fh, $filename) = tempfile( CLEANUP=>1 );
			print $fh $response->decoded_content;
			close $fh;
			ok ( -s $filename, "File $filename not empty" ); 
						
			my $is_valid = _validate_dwca( $filename );
			ok( $is_valid, "File $filename is a valid darwin core archive" );
		}		
	}
}

# Read data from tsv file. Returns hash.
# Argument: Full path to file
sub _read_data {
	my $path = shift;

	open my $fh, '<', $path or die $!;
	my @lines = <$fh>;
	close $fh;

	return( _read_tsv( @lines ));	
}

# Given a Google Sheets URL, returns the data 
# in a hash
sub _get_googlesheets_data {
	my $url = shift;
	
	# load whole sheet into array
	my @arr = `curl $url`;

	return ( _read_tsv( @arr ) );
}

# Read a list containing the lines of a tsv file
# and and stores it in a hash, with column names as keys
# containing the column data. 
# Argument: list
sub _read_tsv {
	my @arr = @_;

	my @arr_spl = map { [split("\t", $_)] } @arr;
	my @transposed;
	foreach my $j (0..$#{$arr_spl[0]}) {
		push(@transposed, [map $_->[$j], @arr_spl]);
	}
	
	my %table;
	foreach my $i ( 0..$#transposed ) {
		my @curr = @{$transposed[$i]};
		# remove trailing whitespaces
		@curr = map { $_ =~ s/\s+$//g; $_ } @curr;
		my $colname = shift @curr;;
		$table{$colname} = \@curr;
	}

	return %table;
}

# This subroutine uses the online Darwin Core validator at GBif.
# Arguments: a valid URL pointing to a Darwin Core archive file
sub _validate_online {
	my $url = shift;
	
	# Validate using Darwin Core Archive validator
	my $req_url = "http://tools.gbif.org/dwca-validator/validatews.do?archiveUrl=$url";
	my $ua = LWP::UserAgent->new;
	my $response = $ua->get( $req_url );
	ok( $response->is_success, "GBif server responding to request" );
	
	# Check validation result. 
	# XX Unfortunately, if the file was not found or similar, the response is still a success
	#  but not valid json, so the following will crap out...
	my $jp = JSON::Path->new("\$.valid");
	my $val = $jp->value( $response->decoded_content );
	ok ( $val==1, "Response is a valid Darwin Core Archive" );	
}


# use dwca-validator (https://github.com/gbif/dwca-validator)
# to validate a given darwin core archive file in zip 
# format
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
