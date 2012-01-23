#!/usr/bin/perl

use strict;
use warnings;


use AnyEvent;
use AnyEvent::Feed;
use Sys::Syslog qw(:standard);
use Redis;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Encode;
use Config::Simple;
use RSS2POD::FestText2Wav;
use JSON;
use Audio::ConvTools qw/:DEFAULT :Tmp :Log/;
use threads;
use Getopt::Long;

#Initiate configuration file========================================================
my $conf_file_path;
GetOptions(
	"conf=s" => \$conf_file_path,
);
$conf_file_path = defined $conf_file_path ? $conf_file_path : "../config/rss2pod.conf";


my $config = new Config::Simple($conf_file_path);

#End initate config options=========================================================
#initiate syslog
openlog( "RssVoicefyer", "pid,perror,nofatal", "local0" );

my $search_for_new_feed = AnyEvent->timer(
	after    => 0, #$config->param("general.check_feed_interval"),
	interval => $config->param("general.check_feed_interval"),
	cb       => \&manager_voicification,
);

#initiate work cycle
my $worckcycle = AnyEvent->condvar;
$worckcycle->recv;

=head3
Put new rss item into database
=cut

sub manager_voicification() {

	my $redis = Redis->new();
	while ( my $item_json = $redis->lpop("feeds:vqueuelist") ) {
		my $json     = JSON->new->allow_nonref;
		my $item_txt = $json->decode($item_json);
		syslog( 'info', "Start to voicefy text " . $item_txt->{text} );
		my $txt_wave = voicefy_via_server( $item_txt->{lang}, $item_txt->{text} );
		if(defined $txt_wave && !($txt_wave eq "")){
			syslog( 'info', "Voicefication OK" );	
		}else{
			syslog( 'info', "Error in voicefication" );
		}
		
		my $file_name = $item_txt->{'file_name'};
		my $feed_id   = $item_txt->{'feed_id'};
		
		save_item_as_mp3( $txt_wave, $file_name );
		my $items_in_list = $redis->lpush( "feed:$feed_id:items", $item_json );
		if ( $items_in_list <= 0 ) {
				syslog( "err",
"An arror occured during adding item into Redis:  feed_key feed:$feed_id:items"
				);
			}
	}
	$redis->quit();
}

=head3
Create new thread and perform voicification operation in it.
If thread will work too long, then terminate it.  
=cut

sub voicefy_via_server() {
	my ( $lang, $text ) = @_;

	my $text_wave       = "";
	my $can_use_threads = eval 'use threads; 1';
	if ($can_use_threads) {
		my $work_thread = threads->create(
			sub {
				 $SIG{'KILL'} = sub { threads->exit(); };
				my $txt_wave = get_wave( $lang, $text );
				return $txt_wave;
			}
		);
		my $sleep_counter = 0;
		while ( $work_thread->is_running() && $sleep_counter <= 120) {
			sleep(1);
			$sleep_counter++;
		}
		if($sleep_counter == 120){
			$work_thread->kill('KILL')->detach();
		}
		if($work_thread->is_joinable()){
			syslog("info", "get wave");
			$text_wave = $work_thread->join();			
		}
		
	}
	else {
		$text_wave = get_wave( $lang, $text );
	}

	return $text_wave;
}

=head3
Connect to festival and convert text to speech
=cut
sub get_wave() {
	my ( $lang, $text ) = @_;
	my $festClient = FestText2Wav->new();
	$festClient->festival_connect();
	my $s_voice = $config->param( "voice." . $lang );
	$festClient->voice($s_voice);
	my $txt_wave = $festClient->text2wave_festival_threads( $text, "" );
	$festClient->close_connection();
	return $txt_wave;
}

=head3
Save given wave data into file and сщтмуке ше штещ MP3 
=cut

sub save_item_as_mp3() {
	my ( $wav_data, $file_name ) = @_;
	my $wav_file_location =
	  $config->param("general.tmp_dir") . "/" . $file_name . ".wav";
	my $mp3_file_location =
	  $config->param("general.podcasts_dir") . "/" . $file_name . ".mp3";
	my $result_file_handle;
	open $result_file_handle, ">", $wav_file_location;
	print $result_file_handle $wav_data;
	close $result_file_handle;
	my $status = wav2mp3( $wav_file_location, $mp3_file_location );
	unlink $wav_file_location;
}
