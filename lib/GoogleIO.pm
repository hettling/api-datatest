## This module holds functionality to import data from google spreadsheets and other sources
package GoogleIO;

use strict;
use warnings;

use Data::Dumper;
use Term::Prompt;
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
# Caution: client_id and secret hard-coded
sub create_oauth2_token {
	my ( $self, $filename ) = @_;

	my $oauth2 = Net::Google::DataAPI::Auth::OAuth2->new(
		client_id => '261022607882-tuq7f4hdju3n3dspqvpia3lp50hhhdlr.apps.googleusercontent.com',
		client_secret => 'WdpVp0kXTLXRyJNG94fjWlz3',
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
	# find a worksheet by title
	my $worksheet = $spreadsheet->worksheet( { title => $worksheetname } );
	my @rows = map { $_->content } $worksheet->rows;

	# Net::Google::Spreadsheets unfortunately messes up the column names:
    # all uppercase letters are translated to lower case and special characters such as "_" are missing. 
	# Until this is fixed, we need to get the values explicitly from row 1 (this works).
	my $ncol = scalar( keys ( %{ $rows[0] } ) );
	my @headers = map {$_->content} $worksheet->cells( { 'min-row' => 1, 'max-row' => 1, 
														 'min-col' => 1, 'max-col' => $ncol} );	
	# substitute headers
	for my $row ( @rows ) {
	  HEADER: for my $header ( @headers ) {			
		  for my $k ( keys %{$row} ) {
			  ## strip whitespace and special characters for comparison
			  (my $stripped = lc  $header) =~s/[^a-zA-Z0-9]//g ;
			  if ( $stripped =~ $k ) { 
				  if ( ! ($header eq $k) ) {
					  $row->{ $header } = $row->{ $k };
					  delete $row->{ $k };
					  next HEADER;
				  }
				  
			  }
		  }		  
	  } 
	}
	
	return @rows;	
}


## puts a value into the 'result' column for a given row number
sub set_result {
	my ( $self, $spreadsheetname, $worksheetname, $row, $value ) = @_;

	my $service = $self->_restore_service();

	# Get desired workseet
	my $spreadsheet = $service->spreadsheet( { title => $spreadsheetname } );
	my $worksheet = $spreadsheet->worksheet( { title => $worksheetname } );	

	# Caution: Hard-coded column index
	my $col_idx = 7;
	
	$worksheet->batchupdate_cell( { col=>$col_idx, row=>$row, input_value=>$value } );	
}

## restore service from token file
sub _restore_service {
	my $self = shift;

	my $t = $self->token;
	my $session = retrieve( $t );
	
	my $oauth2 = Net::Google::DataAPI::Auth::OAuth2->new(
		client_id => '261022607882-tuq7f4hdju3n3dspqvpia3lp50hhhdlr.apps.googleusercontent.com',
		client_secret => 'WdpVp0kXTLXRyJNG94fjWlz3',
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
