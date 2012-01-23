
=head1 NAME
GenMp3Pod
=head2 Synopsys
=cut

package GenMp3Pod;

use strict;
use warnings;
use diagnostics;
use POSIX qw(:termios_h);
#use AppConfig;
use Sys::Syslog qw(:standard);
#use Audio::Wav;
use Audio::ConvTools qw/:DEFAULT :Tmp :Log/;
#use FestText2Wav;
use WavMerger;
my $VERSION = "0.001";

sub new {
	my $pkg  = shift;
	my $self = {@_};

	#$GenMp3Pod::voices = %{$voices};
	#$voices =  %{$voices};
	#openlog( "GenMp3Pod", "pid,perror,nofatal", "local0" );
	return bless $self, $pkg;
}

#This function generates mp3 file from stracture text
#argument text is pointer to array thet consist of hash text/lang i.e.
#@{text}[1]->{text}
#@{text}[1]->{lang}
sub genMp3 {
	my ( $self, $wave_list, $file_name, $params ) = @_;
	#my ( $text, $lang );
	#my @file_pieces_names = ();
	#my $single_piece_name;

	#my $festClient = FestText2Wav->new();
	#$festClient->festival_connect();

	#my @audio_wav_pieces = ();
	#foreach my $element ( @{$wave_list} ) {
		#$text = $element->{text};
		#$lang = $element->{lang};
		#my $s_voice = $params->{"voice." . $lang};
		#$single_piece_name = $file_name . $piece_counter . ".wav";
		#$file_pieces_names[$piece_counter] = $single_piece_name;
		#$festClient->voice( $params->{"voice." . $lang} );
		#push @audio_wav_pieces, $festClient->text2wave_festival( $text, "" );		
	#}
	if ( @{$wave_list} > 0 ) {
		syslog("info", "Merge and convert wav2mp3");
		my $merged_wav_file_name = $file_name . ".wav";
		$self->mergeWavPieces( $merged_wav_file_name, $wave_list);
		syslog("info", "start to convert");
		my $status = wav2mp3( $merged_wav_file_name, $file_name );
		unlink $merged_wav_file_name;
	}
}

sub mergeWavPieces {
	my ( $self, $result_file_name, $audio_wav_pieces  ) = @_;
	my $wav_merger         = new WavMerger();
	my $merged_wav_data = $wav_merger->merge_wav($audio_wav_pieces);
	
	my $result_file_handle;
	open $result_file_handle, ">", $result_file_name;
	print $result_file_handle $merged_wav_data;
	close $result_file_handle;
}

sub removeTmpFiles {
	my ( $self, $tmp_files ) = @_;
	my $tmp_file_name;
	my $tmp_files_num = @$tmp_files;
	foreach $tmp_file_name (@$tmp_files) {
		unlink $tmp_file_name;
	}
}

1;
