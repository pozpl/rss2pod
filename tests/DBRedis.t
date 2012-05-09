use Test::More tests => 41;
use Encode;
use lib "../lib";
use Moose;
use RSS2POD::DB::DBRedis;
use Redis;
use JSON;
use RSS2POD::LangUtils::TextHandler qw(prepare_text);
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Data::Dumper;
=begin Redis_database_key_rules
Redis database key rules
id:md5_hex($user_login) - id for user login
user:$user_id:pass - password of user
users:nextId - Id for next user (store all number of users)
user:$new_user_id:login - login for user with id
user:$new_user_id:email - email for user with id


user:$user_id:pod:nexId          - id of new podcast for user
user:$user_id:pod:pod_zset      - list of names of podcasts
user:$user_id:pod:$pod_id:rss_zset - list of rss id's for this podcast
user:$user_id:pod:$pod_id:rss_nextId - id (or weight in z set) of next feed to add to podcast
user:$user_id:pod:" . md5_hex($pod_name) . ":id - id of podcast with such name
user:$user_id:pod:$pod_id:last_chk_time - time of last checking in sec

user:$user_id:pod:$pod_id:pod_files_names - list of stored user podcast files. stored struct {file_path: '$pod_file_name', datatime: '$user_datatime'}
user:$user_id:pod:$pod_id:gen_mp3_stat - status of mp3 generating 

user:$user_id:feeds:feeds_id_zset - set of all id feeds that this user owns
user:$user_id:feeds:$feed_id:last_chk_num - number of last checked item for feed
user:$user_id:feeds:nextId - next id of feed for user

feed:nextId             - next id for feed
feed:$feed_id:items - list of rss items for feed with id. Stores structure {lang: "" , text: "", file_name: ""}
feed:$feed_id:items_md5_zset - zset of md5 summs of items, to check, if new item is already exists in database
feed:$feed_id:items_shift - number of items, that we cut from head of list during application lifetime, the actual number of feeds in list is feeds_shift + count of elements now  in list
feed:" . md5_hex($feed_url) . ":id - id for feed with url stored in #feed_url
feed:$feed_id:title  - name or short description of chanal gained from rss provider.
feed:$feed_id:url - url of feed with id

feeds:set:url            - set of all feeds url's in system
feeds:addurlqueue:set - set of new feeds that need to be added to working process
feeds:vqueuelist - list queue of tasks to voicefy the task is json object wirh fileds: file_name, feed_id, text, lang
=cut

#default test user
my $TEST_USER          = "DEFAULT_TEST_USER";
my $TEST_USER_PASSWORD = "DEFAULT_BLOODY_PASSWORD";
my $TEST_USER_EMAIL    = "test_user\@email.com";

sub open_connection() {

	#my $redis = Redis->new;
## Disable the automatic utf8 encoding => much more performance
	my $redis = Redis->new( encoding => undef );
	return $redis;
}

sub get_db_redis_instance(){
	my $redis    = open_connection();
	my $templater = new Template::Tiny(TRIM => 1);
	my $db_redis = new RSS2POD::DB::DBRedis(
					'redis_connection' => $redis,
					'db_namspace'      => '',
					'templater'        => $templater,					
	);
	
	return $db_redis;
}

sub close_connection() {
	my $redis = shift;
	$redis->quit();
}



############################################
# Usage      : _delete_test_feed("http://som.url")  or _delete_test_feed($feed_id);
# Purpose    : delete feed from database
# Returns    : none
# Parameters : url of the feed to delete or id of that feed
# Throws     : no exceptions
# Comments   : n/a
# See Also   : n/a
sub _delete_test_feed($) {
	my ($feed_url) = @_;
	my $db_redis = RSS2POD::DB::DBRedis->new();
	$db_redis->del_feed($feed_url);
}



sub check_get_feeds_urls() {
	#PREPARE
	my $redis = open_connection();

	my @urls_list = (
		'http://url1.io', 'http://url2.io', 'http://url3.io', 'http://url4.io',
		'http://url4.io',
	);

	my %urls_hash;
	@urls_hash{@urls_list} = ();

	my $db_redis = get_db_redis_instance();

	#add some new urls to the feeds urls set
	for my $single_url (@urls_list) {
		$db_redis->create_feed_for_url($single_url);		
	}
	#EXECUTE
	my @out_feeds_urls_list = $db_redis->get_feeds_urls();
	my %out_feeds_urls_hash;
	@out_feeds_urls_hash{@out_feeds_urls_list} = ();

	#CHECK
	my $is_feed_url_exist_in_out = 1;
	for my $single_url (@urls_list) {
		if ( !exists $out_feeds_urls_hash{$single_url} ) {
			$is_feed_url_exist_in_out = 0;
		}
	}
	
	for my $single_url (@urls_list) {
		$db_redis->del_feed($single_url);		
	}
	$redis->quit();
	return $is_feed_url_exist_in_out;
}

sub check_get_and_del_feed_url_from_queue_of_new_feeds() {
	my $redis = open_connection();
	my $db_redis = get_db_redis_instance();
	#put some urls into the quque of new feeds
	my @urls_list = (
		'http://url1.io', 'http://url2.io', 'http://url3.io', 'http://url4.io',
		'http://url4.io',
	);
	
	#clean queue set
	while ( my $feed_url = $db_redis->get_and_del_feed_url_from_queue_of_new_feeds() ) {}
	
	my %urls_hash;
	@urls_hash{@urls_list} = ();
	for my $single_url (@urls_list) {
		#add feed url to feeds:addurlqueue:set
		$db_redis->add_feed_url_to_queue_of_new_feeds( $single_url );
	}
	
	my $geted_urls_counter = 0;
	while ( my $feed_url = $db_redis->get_and_del_feed_url_from_queue_of_new_feeds() ) {
		$geted_urls_counter += 1 if exists $urls_hash{$feed_url};
	}
	my @unic_urls = keys %urls_hash;
	my $is_all_urls_geted = @unic_urls == $geted_urls_counter ? 1 : 0;

	my $all_ok = 0;
	if ( $is_all_urls_geted) {
		$all_ok = 1;
	}

	$redis->quit();
	return $all_ok;
}

sub check_add_feed_url_to_queue_of_new_feeds() {
	return check_get_and_del_feed_url_from_queue_of_new_feeds();
}

sub check_add_feed_item_to_voicefy_queue() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis

	#by default we put text blob, that is feed item in string form
	#prepare IT
	my $feed_id = 1;                                  #jast test value
	my $item      = "Test feed title   feed content";
	my $item_txt  = RSS2POD::LangUtils::TextHandler::prepare_text($item);
	my $json      = JSON->new->allow_nonref;
	my $file_name = $feed_id . "_" . md5_hex($item_txt);
	$item_txt->{'file_name'} = $file_name;
	$item_txt->{'feed_id'}   = $feed_id;
	my $item_json = $json->encode($item_txt);

	#PUT ITEM INTO DATABASE
	$db_redis->add_feed_item_to_voicefy_queue($item_json);

	#check it
	my $all_ok = 0;
	while ( my $item_from_queue = $db_redis->get_and_del_feed_item_from_voicefy_queue() ) {
		if ( $item_from_queue eq $item_json ) { $all_ok = 1; }
	}

	$redis->quit();
	return $all_ok;
}

sub check_get_and_del_feed_item_from_voicefy_queue() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis

	#PUT text blob into voicefy queue
	my @text_blobs = (
		"I'm happy text blob1",
		"I'm happy text blob2",
		"I'm happy text blob3",
		"I'm happy text blob4",
		"I'm happy text blob5",
	);
	my %text_blobs_hash;
	@text_blobs_hash{@text_blobs} = ();
	for my $text_blob (@text_blobs) {
		$db_redis->add_feed_item_to_voicefy_queue($text_blob);
	}
	my $count_of_getted_blobs = 0;

	#GET
	while ( my $item_from_bd = $db_redis->get_and_del_feed_item_from_voicefy_queue() ) {
		if ( exists $text_blobs_hash{$item_from_bd} ) {
			$count_of_getted_blobs++;
		}
	}

	#Check
	my $all_ok = ( @text_blobs == $count_of_getted_blobs ) ? 1 : 0;

	$redis->quit();
	return $all_ok;
}

sub check_get_feed_id_for_url() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis

	#Prepare feed to add
	my $feed_test_url = "http://my.test.url.com";
	$db_redis->del_feed($feed_test_url);           #delete all feed related information
	$db_redis->create_feed_for_url($feed_test_url);

	#EXECUTE
	my $feed_id = $db_redis->get_feed_id_for_url($feed_test_url);

	#CHECK
	my $got_feed_url = $redis->get( $db_redis->FEED_FEED_ID_URL($feed_id) );

	my $all_ok = $got_feed_url eq $feed_test_url ? 1 : 0;
	$db_redis->del_feed($feed_test_url);
	$redis->quit();
	return $all_ok;
}

sub check_add_item_to_feed() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis

	#feed item is only JSON encoded text blob but we need text part of it anyway
	#let's create test JSON encoded structure
	#by default we put text blob, that is feed item in string form
	#Prepare feed to add
	my $feed_test_url = "http://my.test.url.com";
	$db_redis->del_feed($feed_test_url);           #delete all feed related information
	$db_redis->create_feed_for_url($feed_test_url);
	my $feed_id = $db_redis->get_feed_id_for_url($feed_test_url);

	#prepare test blob
	my $item      = "Test feed title   feed content";
	my $item_txt  = RSS2POD::LangUtils::TextHandler::prepare_text($item);
	my $json      = JSON->new->allow_nonref;
	my $file_name = $feed_id . "_" . md5_hex($item_txt);
	$item_txt->{'file_name'} = $file_name;
	$item_txt->{'feed_id'}   = $feed_id;
	my $item_json = $json->encode($item_txt);

	#EXECUTE
	$db_redis->add_item_to_feed($feed_id, $item_json);

	#CHECK
	my $all_ok = 1;
	my @feed_items = $db_redis->get_all_feed_items($feed_id);
	my %feed_items_hash;
	@feed_items_hash{@feed_items} = ();
	my $item_is_stored_in_list = exists $feed_items_hash{$item_json} ? 1 : 0;

	my $item_hash_is_stored = $db_redis->is_item_alrady_in_feed($feed_id, $item_json);
	
	if($item_is_stored_in_list && $item_hash_is_stored){
		$all_ok = 1; 
	}else{
		$all_ok = 0;
	}
	
	#delete feed
	$db_redis->del_feed($feed_test_url);

	$redis->quit();
	return $all_ok;
}

sub check_is_item_alrady_in_feed() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis

	#Prepare feed to add
	my $feed_test_url = "http://my.test.url.com";
	$db_redis->del_feed($feed_test_url);           #delete all feed related information
	$db_redis->create_feed_for_url($feed_test_url);
	my $feed_id = $db_redis->get_feed_id_for_url($feed_test_url);

	#prepare test blob
	my $item      = "Test feed title   feed content";
	my $item_txt  = RSS2POD::LangUtils::TextHandler::prepare_text($item);
	my $json      = JSON->new->allow_nonref;
	my $file_name = $feed_id . "_" . md5_hex($item_txt);
	$item_txt->{'file_name'} = $file_name;
	$item_txt->{'feed_id'}   = $feed_id;
	my $item_json = $json->encode($item_txt);

	#add item in JSON form into the feed
	$db_redis->add_item_to_feed( $feed_id, $item_json);

	#EXECUTE
	my $is_item_in_feed = $db_redis->is_item_alrady_in_feed( $feed_id, $item_json );

	#CHECK
	my $all_ok = $is_item_in_feed ? 1 : 0;

	$db_redis->del_feed($feed_test_url);    #delete all feed related information
	$redis->quit();
	return $all_ok;
}

sub check_create_feed_for_url() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis

	#prepare clear environment
	my $feed_test_url = "http://my.test.url.com";
	$db_redis->del_feed($feed_test_url);           #delete feed

	#EXECUTE
	my $new_feed_id = $db_redis->create_feed_for_url($feed_test_url);

	#CHECK
	my $feed_id = $db_redis->get_feed_id_for_url($feed_test_url);
	my @all_urls = $db_redis->get_feeds_urls();
	my %all_urls_hash;
	@all_urls_hash{@all_urls} = ();
	
	my $all_ok = ($feed_id != $new_feed_id)              ?    0
				: !exists $all_urls_hash{$feed_test_url} ?    0
				:											  1;
				
		
#	my $all_ok =
#	    !defined $feed_id                                                   ? 0
#	  : !$redis->exists( $db_redis->FEED_NEXTID() )                         ? 0
#	  : !$redis->exists( $db_redis->FEED_FEED_ID_ITEMS($feed_id) )          ? 0
#	  : !$redis->exists( $db_redis->FEED_FEED_URL_ID($feed_test_url) )      ? 0
#	  : !$redis->exists( $db_redis->FEED_FEED_ID_ITEMS_SHIFT($feed_id) )    ? 0
#	  : !$redis->exists( $db_redis->FEED_FEED_ID_TITLE($feed_id) )          ? 0
#	  : !$redis->exists( $db_redis->FEED_FEED_ID_URL($feed_id) )            ? 0
#	  : !$redis->exists( $db_redis->FEED_FEED_ID_ITEMS_MD5_ZSET($feed_id) ) ? 0
#	  : !$redis->exists( $db_redis->FEEDS_SET_URL() )                       ? 0
#	  :                                                                       1;

	#CLEAN
	$db_redis->del_feed($feed_test_url);    #delete feed
	$redis->quit();
	return $all_ok;
}

sub check_del_and_get_old_items_from_feed() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis


	#PREPARE
	my $feed_test_url = "http://my.testold.url.com";
	
	$db_redis->del_feed($feed_test_url);    #delete feed
	my $feed_id = $db_redis->create_feed_for_url($feed_test_url);
	

	#generate a bunch of feed items and add it into the database
	my $json      = JSON->new->allow_nonref;
	my @generated_feed_items;
	for my $item_num ( 1 .. 100 ) {
		my $generated_item = _generate_feed_item( "title  $item_num  text", $feed_id );
		push @generated_feed_items, $generated_item;
		my $item_json = $json->encode($generated_item);
		$db_redis->add_item_to_feed($feed_id,  $item_json);
	}

	#EXECUTE
	my @goten_feed_items = $db_redis->del_and_get_old_items_from_feed( $feed_id, 50 );
#	print Dumper(@goten_feed_items);
	#CHECK
	my $all_ok = 1;
	if ( @goten_feed_items != 50 ) {    #there was 100 generated items
		$all_ok = 0; #print "NUmber of elements is not 50 \n";
	}
	for my $test_feed_item (@goten_feed_items) {    #no item is persitent now
		if ( $db_redis->is_item_alrady_in_feed( $feed_id, $test_feed_item ) ) {
			$all_ok = 0; print "Feed item $test_feed_item \n";
		}
	}

	#CLEAN ENVIRONMENT
	$db_redis->del_feed($feed_test_url);    #delete feed
	$redis->quit();
	return $all_ok;
}

sub check_del_feed() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis


	#prepare clear environment
	my $feed_test_url = "http://my.test.url2.com";
	$db_redis->create_feed_for_url($feed_test_url);
	my $feed_id = $db_redis->get_feed_id_for_url($feed_test_url);

	#EXECUTE
	$db_redis->del_feed($feed_test_url);

	#CHECK
	my $all_ok =
	    !defined $feed_id                                                  ? 0
	  : $redis->exists( $db_redis->FEED_FEED_ID_ITEMS($feed_id) )          ? 0
	  : $redis->exists( $db_redis->FEED_FEED_URL_ID($feed_test_url) )      ? 0
	  : $redis->exists( $db_redis->FEED_FEED_ID_ITEMS_SHIFT($feed_id) )    ? 0
	  : $redis->exists( $db_redis->FEED_FEED_ID_TITLE($feed_id) )          ? 0
	  : $redis->exists( $db_redis->FEED_FEED_ID_URL($feed_id) )            ? 0
	  : $redis->exists( $db_redis->FEED_FEED_ID_ITEMS_MD5_ZSET($feed_id) ) ? 0
	  :                                                                      1;

	#CLEAN
	#delete manualy
	if ( !$all_ok ) {
		$redis->del( $db_redis->FEED_FEED_ID_ITEMS($feed_id) );
		$redis->del( $db_redis->FEED_FEED_URL_ID($feed_test_url) );
		$redis->del( $db_redis->FEED_FEED_ID_ITEMS_SHIFT($feed_id) );
		$redis->del( $db_redis->FEED_FEED_ID_TITLE($feed_id) );
		$redis->del( $db_redis->FEED_FEED_ID_URL($feed_id) );
		$redis->del( $db_redis->FEED_FEED_ID_ITEMS_MD5_ZSET($feed_id) );
	}
	close_connection();
	return $all_ok;
}

sub check_add_new_user() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis


	#PREPARE
	$db_redis->delete_user($TEST_USER);

	#EXECUTE
	$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD, $TEST_USER_EMAIL );

	#CHECK
	my $user_id = $redis->get( $db_redis->ID_USER_LOGIN($TEST_USER) );
	my $all_ok =
	    !defined $user_id                                                        ? 0
	  : !$redis->exists( $db_redis->USER_USER_ID_PASS($user_id) )                ? 0
	  : !$redis->exists( $db_redis->USERS_NEXTID() )                             ? 0
	  : !$redis->exists( $db_redis->USER_USER_ID_LOGIN($user_id) )               ? 0
	  : !$redis->exists( $db_redis->USER_USER_ID_EMAIL($user_id) )               ? 0
	  : !$redis->exists( $db_redis->USER_USER_ID_POD_NEXTID($user_id) )          ? 0
	  : !$redis->exists( $db_redis->USER_USER_ID_POD_POD_ZSET($user_id) )        ? 0
	  : !$redis->exists( $db_redis->USER_USER_ID_FEEDS_FEEDS_ID_ZSET($user_id) ) ? 0
	  : !$redis->exists( $db_redis->USER_USER_ID_FEEDS_NEXTID($user_id) )        ? 0
	  :                                                                            1;

	#CLEAN
	$db_redis->delete_user($TEST_USER);
	close_connection();
	return $all_ok;
}

sub check_delete_user() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis


	#PREPARE
	$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD, $TEST_USER_EMAIL );
	my $user_id = $redis->get( $db_redis->ID_USER_LOGIN($TEST_USER) );

	#EXECUTE
	$db_redis->delete_user($TEST_USER);

	#CHECK
	#check all necessary fields
	my $all_ok =
	    !defined $user_id                                                       ? 0
	  : $redis->exists( $db_redis->USER_USER_ID_PASS($user_id) )                ? 0
	  : $redis->exists( $db_redis->USER_USER_ID_LOGIN($user_id) )               ? 0
	  : $redis->exists( $db_redis->USER_USER_ID_EMAIL($user_id) )               ? 0
	  : $redis->exists( $db_redis->USER_USER_ID_POD_NEXTID($user_id) )          ? 0
	  : $redis->exists( $db_redis->USER_USER_ID_POD_POD_ZSET($user_id) )        ? 0
	  : $redis->exists( $db_redis->USER_USER_ID_FEEDS_FEEDS_ID_ZSET($user_id) ) ? 0
	  : $redis->exists( $db_redis->USER_USER_ID_FEEDS_NEXTID($user_id) )        ? 0
	  :                                                                           1;

   #check pattern on database keys, we do not check podcast specific keys in previous test
	if ( defined $user_id ) {
		my @user_pattern_keys = $redis->keys("user:$user_id:*");
		if ( @user_pattern_keys > 0 ) {
			$all_ok = 0;
		}
	}
	if ( defined $user_id && !$all_ok ) {
		$redis->del( $db_redis->USER_USER_ID_PASS($user_id) );
		$redis->del( $db_redis->USER_USER_ID_LOGIN($user_id) );
		$redis->del( $db_redis->USER_USER_ID_EMAIL($user_id) );
		$redis->del( $db_redis->USER_USER_ID_POD_NEXTID($user_id) );
		$redis->del( $db_redis->USER_USER_ID_POD_POD_ZSET($user_id) );
		$redis->del( $db_redis->USER_USER_ID_FEEDS_FEEDS_ID_ZSET($user_id) );
		$redis->del( $db_redis->USER_USER_ID_FEEDS_NEXTID($user_id) );

		#delete keys by pattern
		$redis->del("user:$user_id:*");
	}
	close_connection();
	return $all_ok;
}

sub check_is_user_exists() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis


	#PREPARE
	$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD, $TEST_USER_EMAIL );

	#EXECUTE
	my $is_user_exists = $db_redis->is_user_exists($TEST_USER);

	#CHECK
	my $all_ok =
	   !$is_user_exists                                                 ? 0
	  : $db_redis->is_user_exists( $TEST_USER . "_no_such_user_login" ) ? 0
	  :                                                                   1;

	#CLEAN ENVIRONMENT
	$db_redis->delete_user($TEST_USER);
	close_connection();
	return $all_ok;
}

sub check_update_user_password() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = RSS2POD::DB::DBRedis->new();    #connect to local redis

	#PREPARE
	$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD, $TEST_USER_EMAIL );

	#EXECUTE
	my $new_pass_for_test_user = 'BRAND_NEW_PASSWORD';
	$db_redis->update_user_password( $TEST_USER, $new_pass_for_test_user );

	#CHECK
	my $is_new_pass_valid =
	  $db_redis->is_user_password_valid( $TEST_USER, $new_pass_for_test_user );
	my $all_ok = $is_new_pass_valid ? 1 : 0;

	#CLEAN ENVIRONMENT
	$db_redis->delete_user($TEST_USER);
	close_connection();
	return $all_ok;
}

sub check_is_user_password_valid() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis


	#PREPARE
	$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD, $TEST_USER_EMAIL );

	#EXECUTE
	my $new_pass_for_test_user = 'BRAND_NEW_PASSWORD';

	#$db_redis->update_user_password($TEST_USER, $new_pass_for_test_user );
	my $is_pass_valid =
	  $db_redis->is_user_password_valid( $TEST_USER, $TEST_USER_PASSWORD );
	my $is_new_pass_valid =
	  $db_redis->is_user_password_valid( $TEST_USER, $new_pass_for_test_user );

	#CHECK
	my $all_ok =
	    $is_new_pass_valid ? 0
	  : $is_pass_valid     ? 1
	  :                      0;

	#CLEAN ENVIRONMENT
	$db_redis->delete_user($TEST_USER);
	close_connection();
	return $all_ok;
}

sub check_update_user_email() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis

	#PREPARE
	$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD, $TEST_USER_EMAIL );
	my $new_email_to_update = 'some@new.email';

	#EXECUTE
	$db_redis->update_user_email( $TEST_USER, $new_email_to_update );

	#CHECK
	my $geted_email = $db_redis->get_user_email($TEST_USER);
	my $all_ok = ( $new_email_to_update eq $geted_email ) ? 1 : 0;

	#CLEAN ENVIRONMENT
	$db_redis->delete_user($TEST_USER);
	close_connection();
	return $all_ok;
}

sub check_get_user_email() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis


	#PREPARE
	$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD, $TEST_USER_EMAIL );

	#EXECUTE
	my $geted_email = $db_redis->get_user_email($TEST_USER);

	#CHECK
	my $all_ok = ( $TEST_USER_EMAIL eq $geted_email ) ? 1 : 0;

	#CLEAN ENVIRONMENT
	$db_redis->delete_user($TEST_USER);
	close_connection();
	return $all_ok;
}

sub check_add_user_podcast() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis

	#PREPARE
	$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD, $TEST_USER_EMAIL );
	my $podcast_label = "Some test podcast";

	#EXECUTE
	$db_redis->add_user_podcast( $TEST_USER, $podcast_label );

	#CHECK
	my $user_id = $redis->get( $db_redis->ID_USER_LOGIN($TEST_USER) );
	my $all_ok =
	    !$redis->exists( $db_redis->USER_USER_ID_POD_NEXTID($user_id) )   ? 0
	  : !$redis->exists( $db_redis->USER_USER_ID_POD_POD_ZSET($user_id) ) ? 0
	  :                                                                     1;
	if ($all_ok) {
		if ( $redis->exists( $db_redis->USER_USER_ID_POD_POD_NAME_ID($user_id) ) ) {
			my $pod_id = $redis->get( $db_redis->USER_USER_ID_POD_POD_NAME_ID($user_id) );

			$all_ok =
			  !$redis->exists(
				$db_redis->USER_USER_ID_POD_POD_ID_RSS_ZSET( $user_id, $pod_id ) ) ? 0
			  : !$redis->exists(
				$db_redis->USER_USER_ID_POD_POD_ID_RSS_NEXTID( $user_id, $pod_id ) ) ? 0
			  : !$redis->exists(
				$db_redis->USER_USER_ID_POD_POD_ID_LAST_CHK_TIME( $user_id, $pod_id ) )
			  ? 0
			  : 1;
		}
		else {
			$all_ok = 0;
		}
	}

	#CLEAN ENVIRONMENT
	$db_redis->delete_user($TEST_USER);
	close_connection();
	return $all_ok;
}

sub check_add_feed_id_to_user_feeds() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis


	#PREPARE
	$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD, $TEST_USER_EMAIL );
	my $feed_id = "1";

	#EXECUTE
	$db_redis->add_feed_id_to_user_feeds( $TEST_USER, $feed_id );

	#CHECK
	my @user_feeds_ids = $db_redis->get_user_feeds_ids($TEST_USER);
	my %user_feed_ids_hash;
	@user_feed_ids_hash{@user_feeds_ids} = ();
	my $all_ok = exists $user_feed_ids_hash{$feed_id} ? 1 : 0;

	#CLEAN ENVIRONMENT
	$db_redis->delete_user($TEST_USER);
	close_connection();
	return $all_ok;
}

sub check_get_user_podcasts_ids() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis

	#PREPARE
	$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD, $TEST_USER_EMAIL );
	my $podcast_label = "Some test podcast";
	my @pod_ids_orig;
	push @pod_ids_orig, $db_redis->add_user_podcast( $TEST_USER, $podcast_label );
	push @pod_ids_orig, $db_redis->add_user_podcast( $TEST_USER, $podcast_label . '2' );
	push @pod_ids_orig, $db_redis->add_user_podcast( $TEST_USER, $podcast_label . '3' );
	my $number_of_podcasts = $#pod_ids_orig;
	my %pod_ids_orig_hash;
	@pod_ids_orig_hash{@pod_ids_orig} = ();

	#EXECUTE
	my @user_podcast_ids = $db_redis->get_user_podcasts_ids($TEST_USER);

	#CHECK
	my $all_ok = 1;
	if ( $#user_podcast_ids != $number_of_podcasts ) {
		for my $pod_id (@pod_ids_orig) {
			if ( !exists $pod_ids_orig_hash{$pod_id} ) {
				$all_ok = 0;
			}
		}
	}

	#CLEAN ENVIRONMENT
	$db_redis->delete_user($TEST_USER);
	close_connection();
	return $all_ok;
}

sub check_get_user_podcasts_id_title_map() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis

	#PREPARE
	$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD, $TEST_USER_EMAIL );
	my $podcast_label = "Some test podcast";

	my %pod_id_lable_hash;
	for my $add_pod_index ( 1 .. 3 ) {
		my $new_pod_lable = $podcast_label . $add_pod_index;
		my $pod_id = $db_redis->add_user_podcast( $TEST_USER, $new_pod_lable );
		$pod_id_lable_hash{$pod_id} = $new_pod_lable;

	}

	#EXECUTE
	my %user_podcast_id_lable_hash =
	  $db_redis->get_user_podcasts_id_title_map($TEST_USER);

	#CHECK
	my $all_ok = 1;
	keys %pod_id_lable_hash;    #RESET HASH ITERATOR,
	while ( my ( $pod_id_orig, $pod_lable_orig ) = each %pod_id_lable_hash ) {
		my $elem_ok =
		    ( !exists $user_podcast_id_lable_hash{$pod_id_orig} ) ? 0
		  : !( $user_podcast_id_lable_hash{$pod_id_orig} eq $pod_lable_orig ) ? 0
		  :                                                              1;
		if ( !$elem_ok ) {
			$all_ok = 0;
		}
	}

	#CLEAN ENVIRONMENT
	$db_redis->delete_user($TEST_USER);

	close_connection();
	return $all_ok;
}

sub check_get_user_podcasts_titles() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis


	#PREPARE
	$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD, $TEST_USER_EMAIL );
	my $podcast_label = "Some test podcast";

	my %pod_id_lable_hash;
	for my $add_pod_index ( 1 .. 3 ) {
		my $new_pod_lable = $podcast_label . $add_pod_index;
		my $pod_id = $db_redis->add_user_podcast( $TEST_USER, $new_pod_lable );
		$pod_id_lable_hash{$pod_id} = $new_pod_lable;

	}

	#EXECUTE
	my @user_podcasts_titles = $db_redis->get_user_podcasts_titles($TEST_USER);

	#CHECK
	my %user_podcasts_titles_hash;
	@user_podcasts_titles_hash{@user_podcasts_titles} = ();

	my $all_ok = 1;
	keys %pod_id_lable_hash;    #RESET HASH ITERATOR,
	for my $pod_lable ( values %pod_id_lable_hash ) {
		if ( !exists $user_podcasts_titles_hash{$pod_lable} ) {
			$all_ok = 0;
		}
	}

	#CLEAN ENVIRONMENT
	$db_redis->delete_user($TEST_USER);

	close_connection();
	return $all_ok;
}

sub check_get_user_podcast_feeds_ids() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis


	#PREPARE
	$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD, $TEST_USER_EMAIL );

	my $podcast_label = "Some test podcast";
	my $podcast_id = $db_redis->add_user_podcast( $TEST_USER, $podcast_label );

	my @feed_ids_orig;
	for my $feed_id ( 1 .. 4 ) {
		$db_redis->add_feed_id_to_user_podcast( $TEST_USER, $podcast_id, $feed_id );
		push @feed_ids_orig, $feed_id;
	}

	#EXECUTE
	my @user_feeds_ids = $db_redis->get_user_podcast_feeds_ids( $TEST_USER, $podcast_id );

	#CHECK
	my %user_feed_ids_hash;
	@user_feed_ids_hash{@user_feeds_ids} = ();
	my $all_ok = 1;
	for my $feed_id (@feed_ids_orig) {
		if ( !exists $user_feed_ids_hash{$feed_id} ) {
			$all_ok = 0;
		}
	}

	#CLEAN ENVIRONMENT
	$db_redis->delete_user($TEST_USER);
	close_connection();
	return $all_ok;
}

sub check_get_feeds_id_title_map() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis

	#PREPARE
	my @urls_list = (
		'http://url1.io', 'http://url2.io', 'http://url3.io', 'http://url4.io',
		'http://url4.io',
	);

	my %id_feed_title_map_orig;
	my @feeds_ids;
	for my $single_url (@urls_list) {
		my $feed_id = _create_feed($single_url);
		$db_redis->set_feed_title($single_url);
		$id_feed_title_map_orig{$feed_id} = $single_url;
		push @feeds_ids, $feed_id;
	}

	#EXECUTE
	my %feeds_id_title_map = $db_redis->get_feeds_id_title_map( \@feeds_ids );

	#CHECK
	my $all_ok = 1;
	for my $feed_id (@feeds_ids) {
		my $feed_ok =
		    ( !exists $feeds_id_title_map{$feed_id} ) ? 0
		  : !( $feeds_id_title_map{$feed_id} eq $id_feed_title_map_orig{$feed_id} ) ? 0
		  :                                                                           1;
		if ( !$feed_ok ) {
			$all_ok = 0;
		}
	}

	#CLEAN ENVIRONMENT
	for my $single_url (@urls_list) {
		_delete_test_feed($single_url);
	}

	close_connection();
	return $all_ok;
}

sub check_get_user_feeds_ids() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis

	#PREPARE
	$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD, $TEST_USER_EMAIL );
	my @feed_ids_orig;
	for my $feed_id ( 1 .. 4 ) {
		$db_redis->add_feed_id_to_user_feeds( $TEST_USER, $feed_id );
		push @feed_ids_orig, $feed_id;
	}

	#EXECUTE
	my @user_feeds_ids = $db_redis->get_user_feeds_ids($TEST_USER);

	#CHECK
	my %user_feed_ids_hash;
	@user_feed_ids_hash{@user_feeds_ids} = ();
	my $all_ok = 1;
	for my $feed_id (@feed_ids_orig) {
		if ( !exists $user_feed_ids_hash{$feed_id} ) {
			$all_ok = 0;
		}
	}

	#CLEAN ENVIRONMENT
	$db_redis->delete_user($TEST_USER);

	close_connection();
	return $all_ok;
}

sub check_del_user_podcast() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis


	#PREPARE
	$db_redis->$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD,
		$TEST_USER_EMAIL );
	my $user_id       = $redis->get( $db_redis->ID_USER_LOGIN($TEST_USER) );
	my $podcast_label = "brand new podcast";
	$db_redis->add_user_podcast( $TEST_USER, $podcast_label );
	my $pod_id =
	  $redis->get( $db_redis->USER_USER_ID_POD_POD_NAME_ID( $user_id, $podcast_label ) );

	#EXECUTE
	$db_redis->del_user_podcast( $TEST_USER, $podcast_label );

	#CHECK

	my $all_ok =
	    !$redis->exists( $db_redis->USER_USER_ID_POD_NEXTID($user_id) )   ? 0
	  : !$redis->exists( $db_redis->USER_USER_ID_POD_POD_ZSET($user_id) ) ? 0
	  :                                                                     1;
	if ($all_ok) {
		if (
			!$redis->exists(
				$db_redis->USER_USER_ID_POD_POD_NAME_ID( $user_id, $podcast_label )
			)
		  )
		{
			$all_ok =
			  $redis->exists(
				$db_redis->USER_USER_ID_POD_POD_ID_RSS_ZSET( $user_id, $pod_id ) ) ? 0
			  : $redis->exists(
				$db_redis->USER_USER_ID_POD_POD_ID_RSS_NEXTID( $user_id, $pod_id ) ) ? 0
			  : $redis->exists(
				$db_redis->USER_USER_ID_POD_POD_ID_LAST_CHK_TIME( $user_id, $pod_id ) )
			  ? 0
			  : 1;
		}
		else {
			$all_ok = 0;
		}
	}

	#CLEAN ENVIRONMENT
	$db_redis->delete_user($TEST_USER);

	close_connection();
	return $all_ok;
}

#1
sub check_set_new_podcast_item_ready_status() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis


	#PREPARE
	$db_redis->$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD,
		$TEST_USER_EMAIL );
	my $user_id       = $redis->get( $db_redis->ID_USER_LOGIN($TEST_USER) );
	my $podcast_label = "brand new podcast";
	$db_redis->add_user_podcast( $TEST_USER, $podcast_label );
	my $pod_id =
	  $redis->get( $db_redis->USER_USER_ID_POD_POD_NAME_ID( $user_id, $podcast_label ) );

	#EXECUTE
	my $status = 'ok';
	$db_redis->set_new_podcast_item_ready_status( $user_id, $pod_id, $status );

	#CHECK
	my $obtained_status =
	  $redis->get( $db_redis->USER_USER_ID_POD_POD_ID_GEN_MP3_STAT( $user_id, $pod_id ) );
	my $all_ok = 0;
	if ( $obtained_status && $obtained_status eq $status ) {
		$all_ok = 1;
	}

	#CLEAN ENVIRONMENT
	$db_redis->delete_user($TEST_USER);

	close_connection();
	return $all_ok;
}

#2
sub check_get_new_podcast_item_ready_status() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis

	#PREPARE
	$db_redis->$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD,
		$TEST_USER_EMAIL );
	my $user_id       = $redis->get( $db_redis->ID_USER_LOGIN($TEST_USER) );
	my $podcast_label = "brand new podcast";
	$db_redis->add_user_podcast( $TEST_USER, $podcast_label );
	my $pod_id =
	  $redis->get( $db_redis->USER_USER_ID_POD_POD_NAME_ID( $user_id, $podcast_label ) );

	my $status = 'ok';
	$db_redis->set_new_podcast_item_ready_status( $user_id, $pod_id, $status );

	#EXECUTE
	my $obtained_status = $db_redis->get_new_podcast_item_ready_status();

	#CHECK
	my $all_ok = 0;
	if ( $obtained_status && $obtained_status eq $status ) {
		$all_ok = 1;
	}

	#CLEAN ENVIRONMENT
	$db_redis->delete_user($TEST_USER);

	close_connection();
	return $all_ok;
}

#3
sub check_add_pod_file_path_lable_to_podcast() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis


	#PREPARE
	$db_redis->$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD,
		$TEST_USER_EMAIL );
	my $user_id       = $redis->get( $db_redis->ID_USER_LOGIN($TEST_USER) );
	my $podcast_label = "brand new podcast";
	$db_redis->add_user_podcast( $TEST_USER, $podcast_label );
	my $pod_id =
	  $redis->get( $db_redis->USER_USER_ID_POD_POD_NAME_ID( $user_id, $podcast_label ) );

	my %pod_file_struct = (
		file_path => '/home/pozpl/podcast.mp3',
		datatime  => '26.07.1000 12:56',
	);
	my $json = JSON->new->allow_nonref;
	my $encoded_file_struct = $json->encode( \%pod_file_struct );
	
	#EXECUTE
	$db_redis->add_pod_file_path_lable_to_podcast( $user_id, $pod_id, $encoded_file_struct);
	
	#CHECK
	my @file_paths = $db_redis->get_user_podcast_files_paths($user_id, $pod_id);
	my  %file_paths_hash;
	@file_paths_hash{@file_paths} = ();
	
	my @file_lables = $db_redis->get_user_podcast_files_lables($user_id, $pod_id);
	my %file_lables_hash;
	@file_lables_hash{@file_lables} = ();
	
	my $all_ok = 0;
	
	$all_ok = ! exists($file_paths_hash{ $pod_file_struct{'file_path'} })   ? 0
			  : ! exists($file_lables_hash{ $pod_file_struct{'datetime'} }) ? 0 
			  :																  1;	
	
	#CLEAN
	$db_redis->delete_user($TEST_USER);
	
	close_connection();
	return $all_ok;
}

#4
sub check_get_user_podcast_files_paths() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis

	
	$db_redis->$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD,
		$TEST_USER_EMAIL );
	my $user_id       = $redis->get( $db_redis->ID_USER_LOGIN($TEST_USER) );
	my $podcast_label = "brand new podcast";
	$db_redis->add_user_podcast( $TEST_USER, $podcast_label );
	my $pod_id =
	  $redis->get( $db_redis->USER_USER_ID_POD_POD_NAME_ID( $user_id, $podcast_label ) );

	my %pod_file_struct = (
		file_path => '/home/pozpl/podcast.mp3',
		datatime  => '26.07.1000 12:56',
	);
	my $json = JSON->new->allow_nonref;
	my $encoded_file_struct = $json->encode( \%pod_file_struct );
	
	$db_redis->add_pod_file_path_lable_to_podcast( $user_id, $pod_id, $encoded_file_struct);
	
	#EXECUTE
	my @file_paths = $db_redis->get_user_podcast_files_paths($user_id, $pod_id);
	my  %file_paths_hash;
	@file_paths_hash{@file_paths} = ();
	
	#CHECK
	my $all_ok = 0;
	
	$all_ok = exists($file_paths_hash{ $pod_file_struct{'file_path'} })   ? 1 : 0;	
	
	#CLEAN
	$db_redis->delete_user($TEST_USER);
	
	close_connection();
	return $all_ok;
}

#5
sub check_get_user_podcast_files_lables() {
	
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis

	
	#PREPARE
	$db_redis->$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD,
		$TEST_USER_EMAIL );
	my $user_id       = $redis->get( $db_redis->ID_USER_LOGIN($TEST_USER) );
	my $podcast_label = "brand new podcast";
	$db_redis->add_user_podcast( $TEST_USER, $podcast_label );
	my $pod_id =
	  $redis->get( $db_redis->USER_USER_ID_POD_POD_NAME_ID( $user_id, $podcast_label ) );

	my %pod_file_struct = (
		file_path => '/home/pozpl/podcast.mp3',
		datatime  => '26.07.1000 12:56',
	);
	
	my $json = JSON->new->allow_nonref;
	
	my $encoded_file_struct = $json->encode( \%pod_file_struct );
	
	$db_redis->add_pod_file_path_lable_to_podcast( $user_id, $pod_id, $encoded_file_struct);
	
	#EXECUTE
	my @file_lables = $db_redis->get_user_podcast_files_lables($user_id, $pod_id);
	my %file_lables_hash;
	@file_lables_hash{@file_lables} = ();
	
	#CHECK
	my $all_ok = 0;
	
	$all_ok =  exists($file_lables_hash{ $pod_file_struct{'datetime'} }) ? 1 : 0;
	
	#CLEAN
	$db_redis->delete_user($TEST_USER);
	
	close_connection();
	return $all_ok;
}

#6
sub check_get_amount_of_user_podcast_files() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis

	
	#PREPARE
	$db_redis->$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD,
		$TEST_USER_EMAIL );
	my $user_id       = $redis->get( $db_redis->ID_USER_LOGIN($TEST_USER) );
	my $podcast_label = "brand new podcast";
	$db_redis->add_user_podcast( $TEST_USER, $podcast_label );
	my $pod_id =
	  $redis->get( $db_redis->USER_USER_ID_POD_POD_NAME_ID( $user_id, $podcast_label ) );

	my %pod_file_struct = (
		file_path => '/home/pozpl/podcast.mp3',
		datatime  => '26.07.1000 12:56',
	);
	my $json = JSON->new->allow_nonref;
	
	my $encoded_file_struct = $json->encode( \%pod_file_struct );
	
	$db_redis->add_pod_file_path_lable_to_podcast( $user_id, $pod_id, $encoded_file_struct);
	
	#EXECUTE
	my $user_podcast_files = $db_redis->get_amount_of_user_podcast_files($user_id, $pod_id);
	
	
	#CHECK
	my $all_ok = $user_podcast_files == 1 ? 1 : 0;
	
	#CLEAN
	$db_redis->delete_user($TEST_USER);
	
	
	close_connection();
	return $all_ok;
}

#7
sub check_del_and_get_old_podcasts_from_podlist() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis

	
	#PREPARE
	$db_redis->$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD,
		$TEST_USER_EMAIL );
	my $user_id       = $redis->get( $db_redis->ID_USER_LOGIN($TEST_USER) );
	my $podcast_label = "brand new podcast";
	$db_redis->add_user_podcast( $TEST_USER, $podcast_label );
	my $pod_id =
	  $redis->get( $db_redis->USER_USER_ID_POD_POD_NAME_ID( $user_id, $podcast_label ) );
	
	my $json = JSON->new->allow_nonref;
	for my $pod_idx (1..100){
		my %pod_file_struct = (
			file_path => "/home/pozpl/podcast_$pod_idx.mp3",
			datatime  => '26.07.1000 12:56' . $pod_idx,
		);
		my $encoded_file_struct = $json->encode( \%pod_file_struct );	
		$db_redis->add_pod_file_path_lable_to_podcast( $user_id, $pod_id, $encoded_file_struct);
	}
	
	my $max_podcasts_in_podlist = 50; 
	
	#EXECUTE
	my @old_podcasts = $db_redis->del_and_get_old_podcasts_from_podlist($user_id, 
							$pod_id, $max_podcasts_in_podlist);
	
	
	#CHECK
	my $all_ok = (@old_podcasts == 50) ? 1 : 0;
	
	#CLEAN
	$db_redis->delete_user($TEST_USER);
	
	
	close_connection();
	return $all_ok;
}

#8
sub check_get_podcast_last_check_time() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis

	
	#PREPARE
	$db_redis->$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD,
		$TEST_USER_EMAIL );
	my $user_id       = $redis->get( $db_redis->ID_USER_LOGIN($TEST_USER) );
	my $podcast_label = "brand new podcast";
	$db_redis->add_user_podcast( $TEST_USER, $podcast_label );
	my $pod_id =
	  $redis->get( $db_redis->USER_USER_ID_POD_POD_NAME_ID( $user_id, $podcast_label ) );
	
	my $last_chk_time = '26.07.1000 12:56';
	$db_redis->check_set_podcast_last_check_time($user_id, $pod_id, $last_chk_time);
	
	#EXECUTE
	my $obtained_last_chk_time = $db_redis->get_podcast_last_check_time($user_id, $pod_id);
	
	
	#CHECK
	my $all_ok = ($last_chk_time == $obtained_last_chk_time) ? 1 : 0;
	
	#CLEAN
	$db_redis->delete_user($TEST_USER);
	
	
	close_connection();
	return $all_ok;
}

#9
sub check_set_podcast_last_check_time() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis

	
	#PREPARE
	$db_redis->$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD,
		$TEST_USER_EMAIL );
	my $user_id       = $redis->get( $db_redis->ID_USER_LOGIN($TEST_USER) );
	my $podcast_label = "brand new podcast";
	$db_redis->add_user_podcast( $TEST_USER, $podcast_label );
	my $pod_id =
	  $redis->get( $db_redis->USER_USER_ID_POD_POD_NAME_ID( $user_id, $podcast_label ) );
	
	my $last_chk_time = '26.07.1000 12:56';
	
	#EXECUTE	
	$db_redis->check_set_podcast_last_check_time($user_id, $pod_id, $last_chk_time);
	
	#CHECK
	my $obtained_last_chk_time = $db_redis->get_podcast_last_check_time($user_id, $pod_id);
	my $all_ok = ($last_chk_time == $obtained_last_chk_time) ? 1 : 0;
	
	#CLEAN
	$db_redis->delete_user($TEST_USER);
	
	close_connection();
	return $all_ok;
}

#10
sub check_get_users_feeds_new_items() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis

	
	#PREPARE
	$db_redis->$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD,
		$TEST_USER_EMAIL );
	my $user_id       = $redis->get( $db_redis->ID_USER_LOGIN($TEST_USER) );
	
	my $feed_test_url = "http://my.test.url.com";
	$db_redis->del_feed($feed_test_url);           #delete feed
	
	$db_redis->create_feed_for_url($feed_test_url);
	my $feed_id = $db_redis->get_feed_id_for_url($feed_test_url);
	
	$db_redis->add_feed_id_to_user_feeds( $TEST_USER, $feed_id );
	
	#prepare test blob
	my $item      = "Test feed title   feed content";
	my $item_txt  = LangUtils::TextHandler::prepare_text($item);
	my $json      = JSON->new->allow_nonref;
	my $file_name = $feed_id . "_" . md5_hex($item_txt);
	$item_txt->{'file_name'} = $file_name;
	$item_txt->{'feed_id'}   = $feed_id;
	my $item_json = $json->encode($item_txt);
	
	$db_redis->add_item_to_feed( $item_json, $feed_id );
	
	#EXECUTE
	my @new_items = $db_redis->get_users_feeds_new_items($user_id, $feed_id);
	
	#CHECK
	my $all_ok = (@new_items != 1) 				? 0
			:  !($new_items[0] eq $item_json)   ? 0
			:									  1;
	
	#CLEAN
	$db_redis->delete_user($TEST_USER);
	$db_redis->del_feed($feed_test_url); #delete feed
	
	close_connection();
	return $all_ok;
}

#11
sub check_set_feed_title() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis

	
	#PREPARE
	my $feed_test_url = "http://my.test.url.com";
	$db_redis->del_feed($feed_test_url);           #delete feed
	
	$db_redis->create_feed_for_url($feed_test_url);
	my $feed_id = $db_redis->get_feed_id_for_url($feed_test_url);
	
	my $feed_tile = "brand new title";
	
	#EXECUTE
	$db_redis->set_feed_title($feed_id, $feed_tile);
	
	#CHECK
	my $obtained_title = $db_redis->get_feed_title($feed_id);
	
	my $all_ok = ($obtained_title eq $feed_tile) ? 1 : 0;
	
	#CLEAN
	$db_redis->del_feed($feed_test_url); #delete feed
	
	close_connection();
	return $all_ok;
}

#12
sub check_is_feed_with_this_url_exists() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis

	
	#PREPARE
	my $feed_test_url = "http://my.test.url.com";
	$db_redis->del_feed($feed_test_url);           #delete feed
	
	$db_redis->create_feed_for_url($feed_test_url);
	
	my $is_feed_exists = 0;
	#EXECUTE
	$is_feed_exists = $db_redis->is_feed_with_this_url_exists($feed_test_url);
	
	#CHECK
	my $all_ok = $is_feed_exists ? 1 : 0;
	
	#CLEAN
	$db_redis->del_feed($feed_test_url);           #delete feed
	
	close_connection();
	return $all_ok;
}

#13
sub check_set_user_feed_last_checked_item_num() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis

	
	#PREPARE
	$db_redis->$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD,
		$TEST_USER_EMAIL );
	my $user_id       = $redis->get( $db_redis->ID_USER_LOGIN($TEST_USER) );
	
	my $feed_test_url = "http://my.test.url.com";
	$db_redis->del_feed($feed_test_url);           #delete feed
	
	$db_redis->create_feed_for_url($feed_test_url);
	my $feed_id = $db_redis->get_feed_id_for_url($feed_test_url);
	
	$db_redis->add_feed_id_to_user_feeds( $TEST_USER, $feed_id );
	
	my $check_item_num = 3;
	#EXECUTE
	$db_redis->set_user_feed_last_checked_item_num($user_id, $feed_id, $check_item_num);
	
	#CHECK
	my $test_check_item_num = $db_redis->set_user_feed_last_checked_item_num($user_id, $feed_id, $check_item_num);
	my $all_ok = ($test_check_item_num == $check_item_num) ? 1 : 0;
	
	#CLEAN
	$db_redis->del_feed($feed_test_url);           #delete feed
	$db_redis->delete_user($TEST_USER);
	
	close_connection();
	return $all_ok;
}

#14
sub check_add_feed_id_to_user_podcast() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis

	
	#PREPARE
	$db_redis->$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD,
		$TEST_USER_EMAIL );
	my $user_id       = $redis->get( $db_redis->ID_USER_LOGIN($TEST_USER) );
	my $podcast_label = "brand new podcast";
	$db_redis->add_user_podcast( $TEST_USER, $podcast_label );
	my $pod_id =
	  $redis->get( $db_redis->USER_USER_ID_POD_POD_NAME_ID( $user_id, $podcast_label ) );
	  
	my $feed_test_url = "http://my.test.url.com";
	$db_redis->del_feed($feed_test_url);           #delete feed
	
	$db_redis->create_feed_for_url($feed_test_url);
	my $feed_id = $db_redis->get_feed_id_for_url($feed_test_url);
	
	#EXECUTE
	$db_redis->add_feed_id_to_user_podcast($feed_id);
	
	#CHECK
	my @feeds_ids = $db_redis->get_user_podcast_feed_ids($user_id, $pod_id);
	my %feeds_ids_hash;
	@feeds_ids_hash{@feeds_ids} = ();
	
	my $all_ok = exists($feeds_ids_hash{$feed_id}) ? 1 : 0; 
		
	#CLEAN
	$db_redis->del_feed($feed_test_url);           #delete feed
	$db_redis->delete_user($TEST_USER);
	
	close_connection();
	return $all_ok;
}

#15
sub check_del_user_feed() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis

	
	#PREPARE
	$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD, $TEST_USER_EMAIL );
	my $feed_id = "1";
	$db_redis->add_feed_id_to_user_feeds( $TEST_USER, $feed_id );
	my $user_id       = $redis->get( $db_redis->ID_USER_LOGIN($TEST_USER) );
	
	#EXECUTE
	$db_redis->del_user_feed($user_id, $feed_id);
	
	#CHECK
	my @user_feeds_ids = $db_redis->get_user_feeds_ids($TEST_USER);
	my %user_feed_ids_hash;
	@user_feed_ids_hash{@user_feeds_ids} = ();
	my $all_ok = exists $user_feed_ids_hash{$feed_id} ? 0 : 1;

	#CLEAN ENVIRONMENT
	$db_redis->delete_user($TEST_USER);

	
	close_connection();
	return $all_ok;
}

#16
sub check_del_feed_id_from_user_podcast() {
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis

	
	#PREPARE
	$db_redis->$db_redis->add_new_user( $TEST_USER, $TEST_USER_PASSWORD,
		$TEST_USER_EMAIL );
	my $user_id       = $redis->get( $db_redis->ID_USER_LOGIN($TEST_USER) );
	my $podcast_label = "brand new podcast";
	$db_redis->add_user_podcast( $TEST_USER, $podcast_label );
	my $pod_id =
	  $redis->get( $db_redis->USER_USER_ID_POD_POD_NAME_ID( $user_id, $podcast_label ) );
	  
	my $feed_test_url = "http://my.test.url.com";
	$db_redis->del_feed($feed_test_url);           #delete feed
	
	$db_redis->create_feed_for_url($feed_test_url);
	my $feed_id = $db_redis->get_feed_id_for_url($feed_test_url);
	
	$db_redis->add_feed_id_to_user_podcast($feed_id);
	
	#EXECUTE
	$db_redis->del_feed_id_from_user_podcast($user_id, $pod_id, $feed_id);
	
	#CHECK
	my @feeds_ids = $db_redis->get_user_podcast_feed_ids($user_id, $pod_id);
	my %feeds_ids_hash;
	@feeds_ids_hash{@feeds_ids} = ();
	
	my $all_ok = exists($feeds_ids_hash{$feed_id}) ? 0 : 1; 
		
	#CLEAN
	$db_redis->del_feed($feed_test_url);           #delete feed
	$db_redis->delete_user($TEST_USER);
	
	
	close_connection();
	return $all_ok;
}

#17
sub check_get_filled_key(){
	my $redis    = open_connection();              #connect to local redis
	my $db_redis = get_db_redis_instance();    #connect to local redis

	my $filled_key = $db_redis->get_filled_key("ID_LOGIN", {login => 'pozpl'});
	
	my $all_ok = ($filled_key eq 'id:pozpl');
	
	return $all_ok;
}


ok(check_get_filled_key(), "Filled key template");

ok( check_get_feeds_urls(), "Get feeds urls works fine" );
ok(
	check_get_and_del_feed_url_from_queue_of_new_feeds(),
	"Get and del value from the set of urls works"
);
ok( check_add_feed_url_to_queue_of_new_feeds(),
	"Add value to the set of new urls works" );
ok( check_add_feed_item_to_voicefy_queue(), "Add feed item to the voicefy queue works" );
ok(
	check_get_and_del_feed_item_from_voicefy_queue(),
	"Get and delete feed item from the voicefy queue"
);
ok( check_add_item_to_feed(),                "Add item to a feed works" );
ok( check_is_item_alrady_in_feed(),          "Check is a item already in a feed works" );
ok( check_create_feed_for_url(),             "Create new feed for a provided URL works" );
ok( check_del_and_get_old_items_from_feed(), "get and delete old items function works" );
ok( check_del_feed(),                        "feed deletion is ok" );
ok( check_set_new_podcast_item_ready_status(),  "set new podcast item ready status ok" );
ok( check_add_pod_file_path_lable_to_podcast(), "add filre path lable to podcast ok" );
ok( check_get_user_podcast_files_paths(),       "get podcast's file paths ok" );
ok( check_get_user_podcast_files_lables(),      'get users podcast file lables ok' );
ok( check_get_amount_of_user_podcast_files(),   'get podcast files amount ok' );
ok(
	check_del_and_get_old_podcasts_from_podlist(),
	"get and delete old podcasts from podlist"
);
ok( check_get_podcast_last_check_time(), "get last time podcast was checked" );
ok( check_set_podcast_last_check_time(), 'set last time podcast was checked' );
ok( check_get_users_feeds_new_items(),
	'get new items that was added to the user feeds since last check' );
ok( check_add_new_user(),                        "add new user ok" );
ok( check_delete_user(),                         'delete user ok' );
ok( check_is_user_exists(),                      'is user exists' );
ok( check_update_user_password(),                'update user\' pasword ok' );
ok( check_is_user_password_valid(),              'get user password hash ok ' );
ok( check_update_user_email(),                   "update user email ok" );
ok( check_get_user_email(),                      "get user email ok" );
ok( check_add_user_podcast(),                    'add podcast to user' );
ok( check_add_feed_id_to_user_feeds(),           "add new feed id to user feeds list" );
ok( check_get_user_podcasts_ids(),               "get user's podcasts ids" );
ok( check_get_user_podcasts_id_title_map(),      'get map of id->podcast title' );
ok( check_get_user_podcasts_titles(),            "get titles of user's podcasts" );
ok( check_get_user_podcast_feeds_ids(),          "get list of user's feeds ids" );
ok( check_get_user_podcast_feeds_id_title_map(), "get map of user's feed{id}=title" );
ok( check_get_user_feeds_ids(),                  "get user's feeds ids" );
ok( check_del_user_podcast(),                    "delete user podcast" );
ok( check_set_feed_title(),                      "add new feed to database" );
ok( check_is_feed_with_this_url_exists(), "is feed with given URL exists in database" );
ok(
	check_set_user_feed_last_checked_item_num(),
	"set user's feed last checked element number"
);
ok( check_add_feed_id_to_user_podcast(), "add feed id to user's podcast" );
ok( check_del_user_feed(), "delete feed id from user's list and all user's podcasts" );
ok( check_del_feed_id_from_user_podcast(), "delete feed id from user's podcast" );
ok( check_get_feed_id_for_url(),           "get feed id for URL ok" );


############################################
# Usage      : _create_test_feed("http://som.url")  or _delete_test_feed($feed_id);
# Purpose    : delete feed from database
# Returns    : none
# Parameters : url of the feed to delete or id of that feed
# Throws     : no exceptions
# Comments   : n/a
# See Also   : n/a
sub _create_test_feed() {
	my ($feed_url) = @_;

	my $db_redis = get_db_redis_instance();    #connect to local redis

	$db_redis->del_feed($feed_url);                #delete all feed related information
	my $feed_id = $db_redis->create_feed_for_url($feed_url);
	
	return $feed_id;
}


############################################
# Usage      : _generate_feed_item("some text");
# Purpose    : genrate item in text form
# Returns    : json serialysed feed item
# Parameters : text string, feed id
# Throws     : no exceptions
# Comments   : Generate feed item based on an input text field
# See Also   : n/a
sub _generate_feed_item() {
	my ( $item_raw, $feed_id ) = @_;

	my $item_txt  = RSS2POD::LangUtils::TextHandler::prepare_text($item_raw);
	my $json      = JSON->new->allow_nonref;
	my $file_name = $feed_id . "_" . md5_hex($item_txt);
	$item_txt->{'file_name'} = $file_name;
	$item_txt->{'feed_id'}   = $feed_id;
	my $item_json = $json->encode($item_txt);

	return $item_json;
}
