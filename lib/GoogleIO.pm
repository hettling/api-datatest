## This module holds functionality to import data from google spreadsheets and other sources
package GoogleIO;

use strict;
use warnings;

use Data::Dumper;
use Term::Prompt;
use File::Compare;
use Storable;
use Net::Google::DataAPI::Auth::OAuth2;
use Net::Google::Spreadsheets;
use Net::Google::Spreadsheets::Worksheet;

use parent 'Exporter';

our @EXPORT = qw( create_oauth2_token get_worksheet_rows );

sub new {
	my $class = shift;
	my %args = @_;
	my $self = \%args;
	return bless $self, $class;	
}

# Getter/setter for authentication token
sub token {
	my $self = shift;
	$self->{'token'} = shift if @_;

	return $self->{'token'};
}

# Create an oauth2 token for google spreadsheets and save to file.
sub create_oauth2_token {
	my ( $self, $client_id, $client_secret, $filename ) = @_;

	my $oauth2 = Net::Google::DataAPI::Auth::OAuth2->new(
		client_id => $client_id,
		client_secret => $client_secret,
		scope => ['http://spreadsheets.google.com/'],
		);
	
	my $url = $oauth2->authorize_url();
	
    #you will need to put code here and receive token
	print "OAuth URL, get code: $url\n";
	my $code = prompt('x', 'paste the code: ', '', ''); 
	my $ac = $oauth2->get_access_token( $code ) or die;

	# save token	
	my $session = $ac->session_freeze;
	store( $session, $filename );

	$self->token( $filename );

	return $filename;	
}

# Given a serialised oauth2 token, a spreadsheet- and a worksheet name,
# retreive the rows of the worksheet as array. Each row is represented as a
# hash with column names as keys and row values as values.
sub get_worksheet_rows {
	my ( $self, $spreadsheetname, $worksheetname ) = @_;
		
	my $service = $self->_restore_service;
	
	# find spreadsheet by key
	my $spreadsheet = $service->spreadsheet( { title => $spreadsheetname } );
	# find worksheet by title
	my $worksheet = $spreadsheet->worksheet( { title => $worksheetname } );
	
	my @rows = map { $_->content } $worksheet->rows;
	
	# If none or only the header row is present, the spreadsheet API
	# will send empty rows, so there is nothing to do
	return @rows if ! scalar @rows;
	
	# Net::Google::Spreadsheets unfortunately messes up the column names:
    # all uppercase letters are translated to lower case and special characters such as "_" are missing. 
	# Until this is fixed, we need to get the values explicitly from the header rows.
	my $ncol = scalar( keys ( %{ $rows[0] } ) );
	
	my @headers = map {$_->content} $worksheet->cells( { 'min-row' => 1, 'max-row' => 1, 
														 'min-col' => 1, 'max-col' => $ncol } );		

 	# substitute headers
	for my $row ( @rows ) {
	  HEADER: for my $header ( @headers ) {			
		  for my $k ( keys %{$row} ) {
			  # strip whitespace and special characters for comparison			  
			  (my $stripped = lc  $header) =~s/[^a-zA-Z0-9]//g ;
			  # also substitute the ones that were set to lower case
			  if ( $stripped =~ $k || (lc ($header) =~ $k) ) { 
				  if ( ! ($header eq $k) ) {					  					  
					  $row->{ $header } = $row->{ $k };
					  delete $row->{ $k };					  
					  next HEADER;
					  ##print Dumper($row);
				  }				  
			  }			  
		  }		  
	  }
	}
		
	return @rows;
}

sub is_updated {
	my ( $self, $spreadsheet, $worksheet ) = @_;
	
	# get cached worksheet
	my $cached_sheet = "cache-${spreadsheet}-${worksheet}.tsv";
	
	# write current worksheet to tsv
	my $current_sheet = "current-sheet.tsv";
	$self->write_sheet_tsv( $spreadsheet, $worksheet, $current_sheet );

	print "Comparing $cached_sheet, $current_sheet \n";
	my $result = compare( $cached_sheet, $current_sheet);
	##unlink( $current_sheet );
	# make the current file the cached file
   	system( "mv $current_sheet $cached_sheet");
	##$self->write_sheet_tsv( $spreadsheet, $worksheet, $cached_sheet );
		
	return $result;
}

## puts a value into the 'result' column for a given row number
sub set_result {
	my ( $self, $spreadsheetname, $worksheetname, $row_indices, $colnames, $values ) = @_;

	my @row_idx = @{ $row_indices };
	my @cols = @{ $colnames };
	my @vals = @{ $values };

	if ( ! scalar(@row_idx) == scalar(@vals) ) {
		die('Number of rows must equal number of values to update');
	}
	
	my $service = $self->_restore_service();

	# Get desired workseet
	my $spreadsheet = $service->spreadsheet( { title => $spreadsheetname } );
	my $worksheet = $spreadsheet->worksheet( { title => $worksheetname } );	

	# find column index
	my @rows = map { $_->content } $worksheet->rows;	
	my $ncol = scalar( keys ( %{ $rows[0] } ) );
	my @headers = map {$_->content} $worksheet->cells( { 'min-row' => 1, 'max-row' => 1, 														 
														 'min-col' => 1, 'max-col' => $ncol} );
	for my $colname( @cols ) {
		if ( ! grep (/$colname/, @headers) ) {
			die("No header found for Column $colname");
		}
	}

	## my( $col_idx )= grep { $headers[$_] eq $colname } 0..$ncol-1;
	##my $col_idx = map { grep { $headers[$_] eq $colname } 0..$ncol-1 } @cols;
	my @col_idx;
	for my $colname ( @cols ) {
		my( $col_idx )= grep { $headers[$_] eq $colname } 0..$ncol-1;
		$col_idx += 1;
		push @col_idx, $col_idx;
	}
	##$col_idx += 1;
	my @update_hashs;
	for my $i ( 0..$#vals ) {
		my $hr = { col=>$col_idx[$i], row=>$row_idx[$i], input_value=>$vals[$i] };
		push @update_hashs, $hr;
	}
	
	## print Dumper( \@update_hashs );
	$worksheet->batchupdate_cell( @update_hashs );
	## $worksheet->batchupdate_cell( { col=>$col_idx, row=>$row_idx, input_value=>$value } );	
}

## write a worksheet to file, with sorted column names
sub write_sheet_tsv {
	my ( $self, $spreadsheetname, $worksheetname, $filename ) = @_;

	# get data
	my @rows = $self->get_worksheet_rows( $spreadsheetname, $worksheetname );

	# get keys
	my $r = $rows[0];
	my @keys = sort( keys( %$r ) );

	# write to file
	open my $fh, '>', $filename or die $!;

	# print header
	for my $k ( @keys ) {
		print $fh $k . "\t";
	}
	print $fh "\n";

	# iterate over rows and write data to file
	for my $row ( @rows ) {
		for my $k ( @keys ) {
			print $fh $row->{$k} . "\t";
		}
		print $fh "\n";
	}
	close $fh;
	##die;
}

## restore service from token file
sub _restore_service {
	my $self = shift;

	my $t = $self->token;
	my $session = retrieve( $t );
	
	my $oauth2 = Net::Google::DataAPI::Auth::OAuth2->new(
		client_id => 'xxx',
		client_secret => 'xxx',
		scope => ['http://spreadsheets.google.com/'],
		);
	
	my $restored_token = Net::OAuth2::AccessToken->session_thaw( $session,
																 auto_refresh => 1,
																 profile => $oauth2->oauth2_webserver );
	
	$oauth2->access_token($restored_token);
	my $service = Net::Google::Spreadsheets->new( auth => $oauth2 );
	
	return $service;
}

1;
