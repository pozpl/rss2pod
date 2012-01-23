#!/usr/bin/perl

use strict;
use warnings;


use AnyEvent;
use AnyEvent::Feed;
use Sys::Syslog qw(:standard);

#use AppConfig qw(:expand :argcount);
use Redis;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Encode;
use Config::Simple;
use JSON;
use RSS2POD::LangUtils::TextHandler qw(prepare_text);
use Getopt::Long;

my $conf_file_path;
GetOptions(
	"conf=s" => \$conf_file_path,
);
$conf_file_path = defined $conf_file_path ? $conf_file_path : "../config/rss2pod.conf";

############Prototypes Section
sub initReaders();
sub check_for_dirs();
############

#Initiate configuration file========================================================
my $config = new Config::Simple($conf_file_path);

#End initate config options=========================================================
#initiate syslog
openlog( "RssFetcher", "pid,perror,nofatal", "local0" );

#List of RSS readers objects
my @rss_readers = ();
check_for_dirs();
initReaders();

sub initReaders() {
	my @feed_readers;

	#get list of urls to work from database
	foreach my $feed_url ( getFeedsFromBD() ) {

#foreach feed create feed listener that will during som intervals of time read the feed
		my $feed_reader = AnyEvent::Feed->new(
			url      => $feed_url,
			interval => $config->param("general.check_feed_interval"),
			on_fetch => \&handle_feed,
		);
		push @feed_readers, $feed_reader;
	}

	my $search_for_new_feed = AnyEvent->timer(
		after    => $config->param("general.check_feed_interval"),
		interval => $config->param("general.check_feed_interval"),
		cb       => sub {
			my $redis = Redis->new();
			unless ( defined($redis) && $redis->ping ) {
				syslog( "err", "Can't establish connection with Redis servr" );
				die "Can not establish connection with Redis";
			}
			while ( my $feed_url = $redis->spop("feeds:addurlqueue:set") ) {
				syslog( "info", "Add to working process feed url  $feed_url" );

				my $feed_reader = AnyEvent::Feed->new(
					url      => $feed_url,
					interval => $config->param("general.check_feed_interval"),
					on_fetch => \&handle_feed,
				);
				push @feed_readers, $feed_reader;
			}
			$redis->quit();
		  }
	);

	#initiate work cycle
	my $worckcycle = AnyEvent->condvar;
	$worckcycle->recv;
}

=head3
Check for work directories and try to create ones if not exists.
=cut

sub check_for_dirs() {
	my $tmp_dir            = $config->param("general.tmp_dir");
	my $podcasts_dir       = $config->param("general.podcasts_dir");
	my $users_podcasts_dir = $config->param("general.user_podcasts_dir");
	if ( !defined $tmp_dir || $tmp_dir eq "" ) {
		syslog( "err", "Tmp dir  is not set, try to use /tmp" );
		$tmp_dir = "/tmp";
	}
	if ( !defined $podcasts_dir || $podcasts_dir eq "" ) {
		syslog( "err",
			"Podcasts dir is not set, try to use /tmp/podcasts_dir" );
		$podcasts_dir = "/tmp/podcasts_dir";
	}
	if ( !defined $users_podcasts_dir || $users_podcasts_dir eq "" ) {
		syslog( "err",
			"Users odcasts dir is not set, try to use /tmp/podcasts_dir/users"
		);
		$podcasts_dir = "/tmp/podcasts_dir/users";
	}

	#try to create tmp dir and podcasts dir, if they do not exists
	if ( !( -e $tmp_dir ) ) {
		mkdir $tmp_dir;
	}
	if ( !( -e $podcasts_dir ) ) {
		mkdir $podcasts_dir;
	}
	if ( !( -e $users_podcasts_dir ) ) {
		mkdir $users_podcasts_dir;
	}
}

=head3
Do some job then new feed entries arrived.
=cut

sub handle_feed() {
	my ( $feed_reader, $new_entries, $feed, $error ) = @_;

	if ( defined $error ) {
		my $feed_url = $feed_reader->url();
		syslog( "err",
			"An error occured during feed: $feed_url  fetching: $error" );
		return;
	}

	# $feed is the XML::Feed object belonging to that fetch.
	for my $hash_entry ( @{$new_entries} ) {
		my ( $hash, $entry ) = @{$hash_entry};

		# $hash a unique hash describing the $entry
		# $entry is the XML::Feed::Entry object of the new entries
		# since the last fetch.
		my $entry_title   = $entry->title;
		my $entry_content = $entry->content->body;
		if ( defined $entry_title && defined $entry_content ) {
			my $feed_url = $feed_reader->url();
			putRssItemIntoDatabase( $feed_url, $entry_content, $entry_title );
		}
	}
}

=head3
This subroutine get all feeds urls from database.
=cut

sub getFeedsFromBD() {
	my @feeds = ();

	my $redis = Redis->new();
	unless ( defined($redis) && $redis->ping ) {
		syslog( "err", "Can't establish connection with Redis servr" );
		die "Can not establish connection with Redis";
	}
	else {
		my @feeds_urls = $redis->smembers("feeds:set:url");

		foreach my $feed_url (@feeds_urls) {
			push( @feeds, $feed_url );
			syslog( "info", "Add to work url: $feed_url" );
		}
		syslog( "info", "all feeds was getted from database " );
		my $feeds_number = @feeds;
		print "Feeds number" . $feeds_number . "\n";
		if ( $feeds_number > 0 ) {
			syslog( 'info', "Start working with $feeds_number feeds" );
		}
	}
	$redis->quit();
	return @feeds;
}

=head3 add_new_feeds_to_process
Check in database queue for new feeds from users, and add this feeds
to the working process. 
=cut

sub add_new_feeds_to_process() {
	my ( $kernel, $feed_readers_handle ) = @_;
	my $redis = Redis->new();
	unless ( defined($redis) && $redis->ping ) {
		syslog( "err", "Can't establish connection with Redis servr" );
		die "Can not establish connection with Redis";
	}
	while ( my $feed_url = $redis->lpop("feeds:addurlqueue:set") ) {
		syslog( "info", "Add to working process feed url  $feed_url" );

		my $feed_reader = AnyEvent::Feed->new(
			url      => $feed_url,
			interval => $config->param("general.check_feed_interval"),
			on_fetch => \&handle_feed,
		);
		push @{$feed_readers_handle}, $feed_reader;
	}
	$redis->quit();
}

=head3
Put new rss item into database
=cut

sub putRssItemIntoDatabase() {
	my ( $feed_url, $feed_content, $feed_title ) = @_;
	my $redis = Redis->new();

	#get id of given feed
	my $feed_url_key = "feed:" . md5_hex($feed_url) . ":id";
	if ( $redis->exists($feed_url_key) ) {
		my $feed_id = $redis->get($feed_url_key);

		#actual number of items in list after addition of new item
		my $items_in_list = 0;
		my $item_num      = 0;

	 #number of items in feed during system work, this is used for item handling
		my $item     = $feed_title . " " . $feed_content;
		my $item_txt = RSS2POD::LangUtils::TextHandler::prepare_text($item);
		if (
			!$redis->zscore( "feed:$feed_id:items_md5_zset",
				md5_hex( $item_txt->{text} ) )
		  )
		{
			my $json = JSON->new->allow_nonref;

			
			my $file_name = $feed_id . "_" . md5_hex($item_txt);
			$item_txt->{'file_name'} = $file_name;

			$item_txt->{'feed_id'} = $feed_id;

			my $item_json = $json->encode($item_txt);
			$redis->lpush( "feeds:vqueuelist", $item_json );

			#for the begining let's delete old items from list
			delete_old_entries( $feed_id, $redis );

		    my $current_time = time();
			my $redis_ok     = $redis->zadd( "feed:$feed_id:items_md5_zset",
				$current_time, md5_hex( $item_txt->{text} ) );

			if ( $config->param("general.debug") ) {
				syslog( "info",
					"Add new items from $feed_url: $item_txt->{text}" );
			}
		}
	}
	else {
		syslog(
			"err", "An error ocured during addin items into feed list: 
						no $feed_url_key is presented, maybe error occured during feed adding!!!"
		);
		syslog( "info", "Try to add proprty feed_id for fix database" );
		my $new_feed_id  = $redis->incr("feed:nextId");
		my $feed_url_key = "feed:" . md5_hex($feed_url) . ":id";
		my $is_ok        = $redis->set( $feed_url_key, $new_feed_id );
		if ( $is_ok eq 'OK' ) {
			syslog( "info", "Successfuly add $feed_url_key for $feed_url" );
		}
	}
	$redis->quit();
}

=head3
Delete old entries from feed item list, and feed md5 zset
=cut

sub delete_old_entries() {
	my ( $feed_id, $redis ) = @_;
	my $list_length        = $redis->llen("feed:$feed_id:items");
	my $max_items_per_feed = $config->param("general.max_items_per_feed");
	if ( $max_items_per_feed < $list_length ) {
		my $trim_num = $list_length - $max_items_per_feed;

		#delete files with tts data from disk
		my @dead_items = $redis->lrange( "feed:$feed_id:items", $trim_num, -1 );
		my @file_names;
		my $json = JSON->new->allow_nonref;
		foreach my $item_json (@dead_items) {
			my $item_s = $json->decode($item_json);
			push @file_names, $item_s->{file_name};
		}
		delete_old_tts_files(@file_names);

		my $redis_ok = $redis->ltrim( "feed:$feed_id:items", $trim_num, -1 );
		my $items_shift =
		  $redis->incrby( "feed:$feed_id:items_shift", $trim_num );
		if ( $config->param("general.debug") ) {
			syslog( "info", "Trim feed $feed_id to $trim_num" );
		}
	}

	#now work with md5 zset
	my $md5_zset_length =
	  $redis->zcount( "feed:$feed_id:items_md5_zset", '-inf', '+inf' );
	my $max_items_per_feed_md5_zset =
	  $config->param("general.max_items_per_feed_md5_zset");
	if ( $md5_zset_length > $max_items_per_feed_md5_zset ) {

		$redis->zremrangebyrank( "feed:$feed_id:items_md5_zset",
			0, $md5_zset_length - $max_items_per_feed_md5_zset );
		if ( $config->param("general.debug") ) {
			syslog( "info",
"Trim feed md5 storage $feed_id to $md5_zset_length - $max_items_per_feed_md5_zset"
			);
		}
	}
}

=head3
Delete files in podcast directory. Where list of files is given as parameter.
=cut

sub delete_old_tts_files() {
	my (@file_names) = @_;
	foreach my $file_name (@file_names) {
		my $mp3_file_location =
		  $config->param("general.podcasts_dir") . "/" . $file_name . ".mp3";
		unlink $mp3_file_location;
	}
}
