package WavMerger;

use strict;
use warnings;
use Sys::Syslog qw(:standard);
use vars qw($VERSION);

my $VERSION = "0.001";

sub new {
	my $pkg  = shift;
	my $self = {@_};
	return bless $self, $pkg;
}

=head3
Take array of wav data as parameter and merge it in sigle wav data scalar.
All operation is going inmemory.
=cut

sub merge_wav() {
	my ( $self, $wav_data_array ) = @_;
	use bytes;
	my $wav_data_aggregator = '';
	my $header;
	foreach my $wav_entity ( @{$wav_data_array} ) {
		$header = substr( $wav_entity, 0, 44 );
		my $data = substr( $wav_entity, 44 );
		$wav_data_aggregator .= $data;
	}
	my $merged_data_length = length($wav_data_aggregator);

	#get last header and update it to get merged one
	my $merged_header =
	  $self->update_wav_header_length( \$header, $merged_data_length );
	my $retun_wav = $merged_header . $wav_data_aggregator;
	no bytes;
	return $retun_wav;
}

=head3
Update wav with new values of length.
Params:
$wav_header_ref - reference to wav header 
$new_data_length - new langth of wav data (without header!)
=cut
sub update_wav_header_length() {
	my ( $self, $wav_header_ref, $new_data_length ) = @_;
	use bytes;
	my $file_length = $new_data_length + 36;
	my $file_length_hex = sprintf( "%x", $file_length );

	my $newBin = '';
	for ( my $i = 0 ; $i < length($file_length_hex) ; $i += 2 ) {

		# note that your hex is 2 bytes per char
		my $hex = substr( $file_length_hex, $i, 2 );

		# turn the hex into a number
		my $dec = hex("0x$hex");

		# pack it
		my $byte = pack( "C", $dec );

		# add it to the binary string
		$newBin = $byte . $newBin;

	}
	while ( length $newBin < 4 ) {
		$newBin .= pack( "C", hex("0x00") );
	}
	my $new_header =
	    substr( $$wav_header_ref, 0, 4 ) 
	  . $newBin
	  . substr( $$wav_header_ref, 8, length($$wav_header_ref) );

	########################################################
	my $data_length = $new_data_length;
	my $data_length_hex = sprintf( "%x", $data_length );
	$newBin = '';
	for ( my $i = 0 ; $i < length($data_length_hex) ; $i += 2 ) {

		# note that your hex is 2 bytes per char
		my $hex = substr( $data_length_hex, $i, 2 );

		# turn the hex into a number
		my $dec = hex("0x$hex");

		# pack it
		my $byte = pack( "C", $dec );

		# add it to the binary string
		$newBin = $byte . $newBin;

	}
	while ( length $newBin < 4 ) {
		$newBin .= pack( "C", hex("0x00") );
	}
	$new_header = substr( $new_header, 0, 40 ) . $newBin;

	no bytes;
	return $new_header;
}

1;
