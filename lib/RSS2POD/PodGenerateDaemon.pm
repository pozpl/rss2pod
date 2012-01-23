
=head1 NAME
RssFeedTaskDaemon
=head2 Synopsys
=head3 Methods
This module is for listening socket or port for new tasks fo feed processing
=cut

package RSS2POD::PodGenerateDaemon;

use strict;
use warnings;
use diagnostics;

use base qw/Net::Daemon/;

use POSIX qw(:termios_h);
use AppConfig;
use Sys::Syslog qw(:standard);
use Redis;
use RSS2POD::ManageUserPodcasts;
use Config::Simple;
use JSON;
use MP3::Tag;

#use threads;
#use Thread::Queue;

my $VERSION = "0.001";

my $config = new Config::Simple("../config/rss2pod.conf");

#my $feedsTaskQueue;

=head2
Jast another supercharjing of function
=cut

sub new ($$;$) {
	my ( $class, $attr, $args ) = @_;
	my ($self) = $class->SUPER::new( $attr, $args );
	$self;
}

# This function does the real work; it is invoked whenever a
# new connection is made.
sub Run ($) {
	my ($self) = @_;
	my ( $line, $sock );
	$sock = $self->{'socket'};
	while (1) {
		$line = $self->getLineFromSocket($sock);

		my ( $user_id, $pod_id, $current_time, $user_datatime );
		if ( $line eq "Hello" ) {
			print $sock $line . "\n";
			$user_id       = $self->getLineFromSocket($sock);
			$pod_id        = $self->getLineFromSocket($sock);
			$current_time  = $self->getLineFromSocket($sock);
			$user_datatime = $self->getLineFromSocket($sock);
			print $sock "Bуe" . "\n";
			syslog( "info",
				"add quey for gen podcast for $user_id, $pod_id, $current_time"
			);
			$self->generate_podcast_file( $user_id, $pod_id, $current_time,
				$user_datatime );
		}
		return;
	}
}

=head3
Create podcast file end send it as answer.
=cut

sub generate_podcast_file() {
	my ( $self, $user_id, $pod_id, $current_time, $user_datatime ) = @_;

	my $redis = Redis->new();    #( server => '127.0.0.1:6379');

#nothing, in future this should be changed to empty mp3 with some noise about donation
	my $mp3_output = "";

	my @podcast_files =
	  $self->get_podcast_file_names( $redis, $user_id, $pod_id, $current_time );
	my $feed_item_list_len = @podcast_files;
	syslog( 'info', "Get $feed_item_list_len in all" );
	if ( @podcast_files > 0 ) {
		syslog( 'info', "Start to merge new podcast" );

		my $pod_file_name =
		    $config->param("general.user_podcasts_dir") . "/" 
		  . $user_id . "_"
		  . $pod_id . "_"
		  . $current_time
		  . "_MP3WRAP.mp3";

		my $is_wrap_sucess = $self->merge_file_peaces_in_one($pod_file_name, \@podcast_files);
		
		#merge feed items into user podcast file
		if ( $is_wrap_sucess == 1 ) {
			$self->add_tags_to_pod_file($pod_file_name, $user_datatime);
			my $json            = JSON->new->allow_nonref;
			my %pod_file_struct = (
				file_path => $pod_file_name,
				datatime  => $user_datatime
			);
			my $redis_ok = $redis->rpush(
				"user:$user_id:pod:$pod_id:pod_files_names",
				$json->encode( \%pod_file_struct )
			);
			$redis->set( "user:$user_id:pod:$pod_id:gen_mp3_stat", "ok" );
			delete_old_user_pod_files( $redis, $user_id, $pod_id );
			syslog( 'info', "podcast $pod_file_name generated" );
		}
		else {
			syslog( "err", "mp3wrap failed ($?): $!" );
			$redis->set( "user:$user_id:pod:$pod_id:gen_mp3_stat",
				"internal_error" );
		}

	}
	else {
		$redis->set( "user:$user_id:pod:$pod_id:gen_mp3_stat", "empty_file" );
	}

	$redis->quit();
}

=head3 add_tags_to_pod_file
=cut
sub add_tags_to_pod_file(){
	my ($self, $filename, $user_datatime) = @_;
	my $mp3 = MP3::Tag->new($filename);
	
	$mp3->title_set("RSS2POD recording " . $user_datatime), 
	$mp3->artist_set("RSS2POD");
	$mp3->album_set("RSS2POD");
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
	$year += 1900;
	$mp3->year_set($year); 
	$mp3->comment_set("rss2pod is cool");
	#$mp3->track_set();
	$mp3->genre_set("podcast");	
	$mp3->update_tags(); 
	$mp3->close();
}

=head3 merge_file_peaces_in_one
	Merge feed entytys files into big one for final podcasting
	
	return 1 if all ok and 0 instead 
=cut
sub merge_file_peaces_in_one(){
	my ($self, $pod_file_name, $podcast_files) = @_;
	
	my $wrap_file_arg = "cat  ";
	
	foreach my $rss_item_file_name (@{$podcast_files}) {		
			my $mp3_file_location =
			    $config->param("general.podcasts_dir") . "/"
			  . $rss_item_file_name . ".mp3";
			if ( -e $mp3_file_location ) {
				$wrap_file_arg = $wrap_file_arg . " " . $mp3_file_location;
			}
		}
		$wrap_file_arg = $wrap_file_arg . " > $pod_file_name";
		my $is_wrap_sucess = 0;

		if ( system($wrap_file_arg) == 0 ) {
			syslog( 'info', " Last chunk of $pod_file_name is generated" );
			$is_wrap_sucess = 1;
		}
		else {
			$is_wrap_sucess = 0;
			syslog( "err", "mp3wrap failed ($?): $!" );
		}
		return $is_wrap_sucess;
}


=head3 Delete old user files
=cut

sub delete_old_user_pod_files() {
	my ( $redis, $user_id, $pod_id ) = @_;
	my $max_amount_of_user_podcasts =
	  $config->param("general.max_podcasts_user_files");
	my $amount_of_files =
	  $redis->llen("user:$user_id:pod:$pod_id:pod_files_names");
	my $files_to_del = $amount_of_files - $max_amount_of_user_podcasts;
	if ( $files_to_del > 10 ) {
		my $json = JSON->new->allow_nonref;
		for ( my $del_idx = 1 .. $files_to_del ) {
			my $file_struct_json =
			  $redis->lpop("user:$user_id:pod:$pod_id:pod_files_names");
			my $file_struct = $json->decode($file_struct_json);
			unlink $file_struct->{"file_path"};
		}
	}
}

=head3 get podcast text from redis
Check if this query is out of time for new query (now approximatly 20 minutes), else get text from last query for this podcast.
Else build text from entires in redis database, and save this snippet of code into cash storage. The cash capacity is about
3-4 items. So we can handle user history up to 4 times down to hte ocean of time.
=cut

sub get_podcast_file_names() {
	my ( $self, $redis, $user_id, $pod_id, $current_time ) = @_;
	my @feed_items = ();

#First of all check if this query is in the time interval for get new text (20 min);

	my $last_time_of_check =
	  $redis->get("user:$user_id:pod:$pod_id:last_chk_time");
	$last_time_of_check = 0 unless defined $last_time_of_check;

	my $json = JSON->new->allow_nonref;

	if ( $redis->exists("user:$user_id:pod:$pod_id:rss_zset") ) {

		#all ok we can proceed
		my @podcast_feeds_ids =
		  $redis->zrange( "user:$user_id:pod:$pod_id:rss_zset", 0, -1 );
		print "user:$user_id:pod:$pod_id:rss_zset \n";
		my @podcast_feeds_url;

		#create text for all feeds
		foreach my $feed_id (@podcast_feeds_ids) {
			my $last_checked =
			  $redis->get("user:$user_id:feeds:$feed_id:last_chk_num");
			$last_checked = 0 unless defined $last_checked;
			syslog( 'info',
"last checked for user:$user_id:feeds:$feed_id:last_chk_num = $last_checked"
			);
			my $feeds_items_shift = $redis->get("feed:$feed_id:items_shift");
			$feeds_items_shift = 0 unless defined $feeds_items_shift;
			my $feeds_list_length = $redis->llen("feed:$feed_id:items");
			$feeds_list_length = 0 unless defined $feeds_list_length;
			my $first_item_position =
			  ( $last_checked + 1 ) - $feeds_items_shift;
			$first_item_position = 0 if $first_item_position < 0;
			my $how_many_items_get = $feeds_list_length - $first_item_position;
			$how_many_items_get = 0 if $how_many_items_get < 0;

			if ( $how_many_items_get > 50 ) {
				$how_many_items_get = 50;
			}
			my @feeds_items_json =
			  $redis->lrange( "feed:$feed_id:items",
				$feeds_list_length - $how_many_items_get,
				$feeds_list_length );
			my $json = JSON->new->allow_nonref;
			foreach my $feed_str_json (@feeds_items_json) {
				push @feed_items, $json->decode($feed_str_json)->{file_name};
			}

			my $feed_item_list_len = @feed_items;
			syslog( 'info', "Get $feed_item_list_len from $feed_id" );

			my $redis_ok = $redis->set(
				"user:$user_id:feeds:$feed_id:last_chk_num",
				$feeds_list_length + $feeds_items_shift
			);
		}

		my $redis_ok = $redis->set( "user:$user_id:pod:$pod_id:last_chk_time",
			$current_time );
	}
	return @feed_items;
}

sub getLineFromSocket() {
	my ( $self, $sock ) = @_;
	my $line;
	if ( !defined( $line = $sock->getline() ) ) {
		if ( $sock->error() ) {
			$self->Error( "Client connection error %s", $sock->error() );
			syslog( "err", "Client connection error  " . $sock->error() );
		}
		$sock->close();
		return '';
	}
	$line =~ s/\s+$//;
	return $line;
}

1;
