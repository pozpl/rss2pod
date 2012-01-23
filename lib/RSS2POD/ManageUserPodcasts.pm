
=head1 NAME
ManageUserPodcasts
=head2 Synopsys
=cut

package RSS2POD::ManageUserPodcasts;

use strict;
use warnings;
use diagnostics;
use POSIX qw(:termios_h);
#use AppConfig qw(:expand :argcount);
use Config::Simple;
use Sys::Syslog qw(:standard);
use RSS2POD::GenMp3Pod;

my $VERSION = "0.001";
my $config;

my $tmp_dir;
my $podcasts_dir;

sub new {
	my ($pkg, $conf_params) = @_;
	my $self = {@_};
	$config = $conf_params;	
	$tmp_dir      = $config->{"general.tmp_dir"};
	$podcasts_dir = $config->{"general.podcasts_dir"};
	if ( !defined $tmp_dir || $tmp_dir eq "" ) {
		syslog( "err", "Tmp dir  is not set, try to use /tmp" );
		$tmp_dir = "/tmp";
	}
	if ( !defined $podcasts_dir || $podcasts_dir eq "" ) {
		syslog( "err",
			"Podcasts dir is not set, try to use /tmp/podcasts_dir" );
		$podcasts_dir = "/tmp/podcasts_dir";
	}
	#try to create tmp dir and podcasts dir, if they do not exists
	if ( !( -e $tmp_dir ) ) {
		mkdir $tmp_dir;
	}
	if ( !( -e $podcasts_dir ) ) {
		mkdir $podcasts_dir;
	}
	return bless $self, $pkg;
}


=head3
Convert single feed item into mp3 and store file
=cut

sub convFeedItem() {
	my ( $self, $wave_queue, $file_name ) = @_;
	my $gen_mp3_pod = RSS2POD::GenMp3Pod->new();
	#my @txt_queue;
	#do some work under txt file
	#my %txt_str_hash = $self->normalyseText($text);
	#push( @txt_queue, \%txt_str_hash );
	#my $txt_struct_ref      = \@txt_queue;
	my $item_full_file_name = $podcasts_dir . "/" . $file_name;
	syslog( "err", "File name $file_name " );
	syslog( "err", "Podcasts dir $podcasts_dir " );
	syslog( "err", "voicefy rss item into $item_full_file_name " );
	$gen_mp3_pod->genMp3( $wave_queue, $item_full_file_name, $config );
	open MP3, $item_full_file_name;
	#assume is a mp3...
	my ( $mp3, $buff );
	while ( read MP3, $buff, 1024 ) {
		$mp3 .= $buff;
	}
	close MP3;
	return $mp3;
}

=head3
This subroutine is chooper function. The main task of it is to 
get text and sweep all unnecessary for text to speech engine from it.
=cut
#
#sub normalyseText() {
#	my ( $self, $text ) = @_;
#	my %txt_hash = ( "text" => "Hellow world " . " big boobs", "lang" => "en" );
#	return %txt_hash;
#}

1;
