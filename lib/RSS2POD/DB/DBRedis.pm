package RSS2POD::DB::DBRedis;

use Moose;
use Redis;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Template::Tiny;
use Data::Dumper;
use Time::HiRes;
with 'RSS2POD::DB::DBAccessFuncs';

=begin Redis_database_key_rules
Redis database key rules
id:md5_hex($user_login)   - id for user login
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

my %REDIS_KEYS_TEMPLATES_HASH = (
	"ID_LOGIN" => "id:[%login%]",
	"USER_ID_PASS" => "user:[%id%]:pass",
	"USERS_NEXT_ID"     => "users:next_id",
	"USER_ID_LOGIN" => "user:[%id%]:ligin",
	"USER_ID_EMAIL" => "user:[%id%]:email",
	"USER_ID_POD_NEXT_ID" => "user:[%id%]:pod:nexId",
	"USER_ID_POD_POD_ZSET" => "user:[%id%]:pod:pod_zset",
	"USER_ID_POD_ID_RSS_ZSET" => "user:[%id%]:pod:[%pod_id%]:rss_zset",
	"USER_ID_POD_ID_RSS_NEXT_ID" => "user:[%id%]:pod:[%pod_id%]:rss_next_id",
	"USER_ID_POD_NAME_ID" => "user:[%id%]:pod:[%name%]:id",
	"USER_ID_POD_ID_LAST_CHK_TIME" => "user:[%id%]:pod:[%pod_id%]:last_chk_time",
	"USER_ID_POD_ID_POD_FILES_NAMES" => "user:[%id%]:pod:[%pod_id%]:pod_files_names",
	"USER_ID_POD_ID_GEN_MP3_STAT" => "user:[%id%]:pod:[%pod_id%]:gen_mp3_stat",
	
	"USER_ID_FEEDS_FEEDS_ID_ZSET" => "user:[%id%]:feeds:feeds_id_zset",
	"USER_ID_FEEDS_ID_LAST_CHK_NUM" => "user:[%id%]:feeds:[%feed_id%]:last_chk_num",
	"USER_ID_FEEDS_NEXT_ID" => "user:[%id%]:feeds:next_id",
	
	"FEED_NEXT_ID" => "feed:next_id",
	"FEED_ID_ITEMS" => "feed:[%id%]:items",
	"FEED_ID_ITEMS_HASH_ZSET" => "feed:[%id%]:items_hash_zset",
	"FEED_ID_ITEMS_SHIFT" => "feed:[%id%]:items_shift",
	"FEED_ID_ITEMS_COUNT" => "feed:[%id%]:items_count",
	"FEED_URL_ID" => "feed:[%url%]:id",
	"FEED_ID_TITLE" => "feed:[%id%]:title",
	"FEED_ID_URL" => "feed:[%id%]:url",

	"FEEDS_SET_URL" => "feeds:set:url",
	"FEEDS_ADDURLQUEUE_SET" => "feeds:addurlqueue:set",
	"FEEDS_VQUEUELIST" => "feeds:vqueuelist",
);

my %REDIS_KEYS_WILDCARDS_TEMPLATES_HASH = (
	'USER_ID' => "user:[%id%]:",
	'USER_ID_POD_ID' => "user:[%id%]:pod:[%pod_id%]:",
	'FEED_ID' => "feed:[%id%]:",
);

#redis connections
has 'redis_connection' => (
	is => 'rw',
	isa => 'Any'
);

#NAMESPACE of redis database to use
has 'db_namespace' => (
	is => 'rw',
	isa => 'Str',
	default => '',
);

has 'templater' => (
	is => 'ro',
	builder => '_instantiate_templater',
);

sub _instantiate_templater(){
	my ($self) = @_;
	
	my $templater = new  Template::Tiny(TRIM => 1);
	
	return $templater;
}

############################################
# Usage      : $dbRedis->get_filled_key("ID_LOGIN", ("login" => md5_hex('pozpl')));
# Purpose    : get propertly filled redis key 
# Returns    : string - redis key
# Parameters : string KEY_ID id of templete for key
#			   hash   key parameters, parameters to fill template
# Throws     : no exceptions
# Comments   : ???
# See Also   : n/a
sub get_filled_key(){
	my ($self, $key_name, $key_args_hash_ref) = @_;
	
	if(!$key_args_hash_ref){
		$key_args_hash_ref = \{};
	}
	
	my $key_template = $REDIS_KEYS_TEMPLATES_HASH{$key_name};
	
	my $filled_key = "";
	$self->templater->process(\$key_template, $key_args_hash_ref, \$filled_key);
	$filled_key = $filled_key ? $filled_key : "";
	
	return $filled_key;
}

############################################
# Usage      : $dbRedis->get_filled_key_wildcard("FEED_ID", ("ID" => md5_hex('pozpl')));
# Purpose    : get propertly filled redis key  wildcard 
# Returns    : string - redis key
# Parameters : string KEY_ID id of templete for key
#			   hash   key parameters, parameters to fill template
# Throws     : no exceptions
# Comments   : example of returned wildcard key feed:10*
#			   this key can be used for massive deletions
# See Also   : n/a
sub get_filled_key_wildcard(){
	my ($self, $key_name, $key_args_hash_ref) = @_;
	
	if(!$key_args_hash_ref){
		$key_args_hash_ref = \{};
	}
	
	my $key_template = $REDIS_KEYS_WILDCARDS_TEMPLATES_HASH{$key_name};
	
	my $filled_key = "";
	$self->templater->process(\$key_template, $key_args_hash_ref, \$filled_key);
	$filled_key = $filled_key ? $filled_key . '*' : "";
	
	return $filled_key;
}

#1
############################################
# Usage      : my @all_urls = get_feeds_urls();
# Purpose    : get all feeds urls from a database and retun it as an array
# Returns    : array of urls strings
# Parameters : none
# Throws     : no exceptions
# Comments   : ???
# See Also   : n/a
sub get_feeds_urls(){
	my ($self) = @_;
	
	my $feeds_urls_set_key = $self->get_filled_key('FEEDS_SET_URL', {});	
		
	my $redis = $self->redis_connection;
	my @feeds_urls = $redis->smembers($feeds_urls_set_key);
	
	return @feeds_urls;	
} 
#2
############################################
# Usage      : my @all_urls = get_and_del_feed_url_from_queue_of_new_feeds();
# Purpose    : get feed url from queue of new feeds that we need to add to downloading process
# Returns    : $feed_url string. Url of the feed from queue
# Parameters : none
# Throws     : no exceptions
# Comments   : ???
# See Also   : n/a
sub get_and_del_feed_url_from_queue_of_new_feeds(){
	my ($self) = @_;
	
	my $feeds_addurlqueue_set_key = $self->get_filled_key('FEEDS_ADDURLQUEUE_SET', {});	
	my $url = $self->redis_connection->spop($feeds_addurlqueue_set_key);
	
	return $url; 
} 
#3
#
############################################
# Usage      : add_feed_url_to_queue_of_new_feeds("http://some/feed");
# Purpose    : add feed url to download queue
# Returns    : none
# Parameters : $feed_url string. Feed to be added
# Throws     : no exceptions
# Comments   : ???
# See Also   : n/a
sub add_feed_url_to_queue_of_new_feeds(){
	my ($self, $url) = @_;
	
	my $feeds_addurlqueue_set_key = $self->get_filled_key('FEEDS_ADDURLQUEUE_SET', {});	
	$self->redis_connection->sadd($feeds_addurlqueue_set_key, $url);
} 

#4
############################################
# Usage      : add_feed_item_to_voicefy_queue("{some_json_here}");
# Purpose    : add afeed item to the voicefy queue
# Returns    : none
# Parameters : string $feed_item - serialysed to JSON feed item
# Throws     : no exceptions
# Comments   : ???
# See Also   : n/a
sub add_feed_item_to_voicefy_queue(){
	my ($self, $feed_item) = @_;
	my $feeds_voicefy_list_key = $self->get_filled_key('FEEDS_VQUEUELIST', {});	
	$self->redis_connection->lpush($feeds_voicefy_list_key, $feed_item);
} 

#5  #get feed item and delete it from queue
############################################
# Usage      : my $feed_item = get_and_del_feed_item_from_voicefy_queue();
# Purpose    : get serialysed to string feed item, and delete it from queue
# Returns    : $feed_item - string serialysed feed_item
# Parameters : none
# Throws     : no exceptions
# Comments   : ???
# See Also   : n/a
sub get_and_del_feed_item_from_voicefy_queue(){
	my ($self) = @_;
	my $feeds_voicefy_list_key = $self->get_filled_key('FEEDS_VQUEUELIST', {});	
	my $feed_item = $self->redis_connection->lpop($feeds_voicefy_list_key);
	
	return $feed_item;
}
#6	
############################################
# Usage      : add_item_to_feed(11, '{some_json object}');
# Purpose    : add item to current feed
# Returns    : none
# Parameters : int $feed_id - id of the feed item to add, 
#			   string $item - serialysed to json feed item
# Throws     : no exceptions
# Comments   : ???
# See Also   : n/a
sub add_item_to_feed(){
	my ($self, $feed_id, $item_seriaiysed) = @_;

	my $feed_id_items_key = $self->get_filled_key('FEED_ID_ITEMS', {"id" =>$feed_id});
	$self->redis_connection->lpush($feed_id_items_key, $item_seriaiysed);
	
	my $feed_id_items_hash_zset_key = $self->get_filled_key('FEED_ID_ITEMS_HASH_ZSET', 
															{"id" =>$feed_id});
	my $item_hash = md5_hex($item_seriaiysed);
	
	
	my $feed_id_items_count_key = $self->get_filled_key('FEED_ID_ITEMS_COUNT', 
															{"id" =>$feed_id});
	my $item_count = $self->redis_connection->incr($feed_id_items_count_key);
	$self->redis_connection->zadd($feed_id_items_hash_zset_key, $item_count, $item_hash);
} 
#7 
############################################
# Usage      : is_item_alrady_in_feed(11, '{some_json object}');
# Purpose    : check presence of the given item in the given feed
# Returns    : true if item is presented false otherwise
# Parameters : int $feed_id - id of the feed item to add, 
#			   string $item - serialysed to json feed item
# Throws     : no exceptions
# Comments   : ???
# See Also   : n/a
sub is_item_alrady_in_feed(){
	my ($self, $feed_id, $item_seriaiysed) = @_;
	
	my $feed_id_items_hash_zset_key = $self->get_filled_key('FEED_ID_ITEMS_HASH_ZSET', 
															{"id" =>$feed_id});
	my $item_hash = md5_hex($item_seriaiysed);
	my $item_score = $self->redis_connection->zscore($feed_id_items_hash_zset_key, $item_hash);
	my $is_in_feed = $item_score ? 1 : 0;
	return $is_in_feed;
} 

############################################
# Usage      : my @feed_items = get_all_feed_items(11);
# Purpose    : get list of all items in the given feed
# Returns    : list of serialysed items
# Parameters : int $feed_id - id of the feed item to add, 
# Throws     : no exceptions
# Comments   : ???
# See Also   : n/a
sub get_all_feed_items(){
	my ($self, $feed_id) = @_;
	my $feed_id_items_key = $self->get_filled_key('FEED_ID_ITEMS', {"id" =>$feed_id});
	my @feed_items = $self->redis_connection->lrange($feed_id_items_key, -1, 1);
	
	return @feed_items;
}
#8	
############################################
# Usage      : create_feed_for_url('http://some/tricky/url/here.cgi');
# Purpose    : add feed into system for given url
# Returns    : $feed_id int. ID of the created feed
# Parameters : url string
# Throws     : no exceptions
# Comments   : ???
# See Also   : n/a
sub create_feed_for_url(){
	my ($self, $url) = @_;
	
	my $feed_url_id_key = $self->get_filled_key('FEED_URL_ID', {'url' => md5_hex($url)});
	my $ret_feed_id = $self->redis_connection->get($feed_url_id_key);	
	
	if(! defined $ret_feed_id){
	
		my $new_id_key = $self->get_filled_key('FEED_NEXT_ID', {});
		my $new_feed_id = $self->redis_connection->incr($new_id_key);
	
		my $feed_id_title_key = $self->get_filled_key('FEED_ID_TITLE', {"id" =>$new_feed_id});
		$self->redis_connection->set($feed_id_title_key, $url);
	
		my $feed_id_url_key = $self->get_filled_key('FEED_ID_URL', {"id" =>$new_feed_id});
		$self->redis_connection->set($feed_id_url_key, $url);
	
		$self->redis_connection->set($feed_url_id_key, $new_feed_id);
	
		my $feed_id_items_shift = $self->get_filled_key('FEED_ID_ITEMS_SHIFT', {"id" =>$new_feed_id});
		$self->redis_connection->set($feed_id_items_shift, 0);
	
		my $feed_url_set_key = $self->get_filled_key('FEEDS_SET_URL', {});
		$self->redis_connection->sadd($feed_url_set_key, $url);
		
		$ret_feed_id = $new_feed_id;
	}
	return $ret_feed_id;
	
}  
#9 
############################################
# Usage      : get_feed_id_for_url('http://some/tricky/url/here.cgi');
# Purpose    : receive feed url and get feed id for this feed if it exists
# Returns    : $feed_id int. ID if feed with such url exists
# Parameters : url string
# Throws     : no exceptions
# Comments   : ???
# See Also   : n/a
sub get_feed_id_for_url(){
	my ($self, $url) = @_;
	
	my $feed_url_id_key = $self->get_filled_key('FEED_URL_ID', {'url' => md5_hex($url)});
	my $feed_id = $self->redis_connection->get($feed_url_id_key);
	
	return $feed_id;
} 
#10
############################################
# Usage      : @old_items = del_and_get_old_items_from_feed($feed_id, $max_items_in_feed);
# Purpose    : trim feed items list, and get all trimmed entities
# Returns    : list of old deleted elements
# Parameters : $feed_id - int id of the feed to be trimmed
#			   $max_items_in_feed - maximum number of elements to be left intact in the feed 
# Throws     : no exceptions
# Comments   : ???
# See Also   : n/a
sub del_and_get_old_items_from_feed(){
	my ($self, $feed_id, $max_items_in_feed) = @_;
	
	my $feed_id_items_key = $self->get_filled_key('FEED_ID_ITEMS', {"id" =>$feed_id});
		
	my $list_length = $self->redis_connection->llen($feed_id_items_key);
	
	my @dead_items = ();
	
	if ( $max_items_in_feed < $list_length ) {
		my $trim_num = $list_length - $max_items_in_feed;

		@dead_items = $self->redis_connection->lrange( $feed_id_items_key, $max_items_in_feed, -1 );		
		my $redis_ok = $self->redis_connection->ltrim( $feed_id_items_key, 0,  $max_items_in_feed - 1);		
		my $feed_id_items_shift_key = $self->get_filled_key('FEED_ID_ITEMS_SHIFT', {"id" =>$feed_id});
		
		#incr shift
		my $items_shift =
		  $self->redis_connection->incrby( $feed_id_items_shift_key, $trim_num );
		
	}

	#now work with md5 zset
	my $feed_id_items_hash_zset_key = $self->get_filled_key('FEED_ID_ITEMS_HASH_ZSET', 
															{"id" =>$feed_id});
	my $md5_zset_length =
	  $self->redis_connection->zcount( $feed_id_items_hash_zset_key, '-inf', '+inf' );
	
	if ( $md5_zset_length > $max_items_in_feed) {
		#instead of lpush zadd add elements to the right, so we need remove from left!!!
		$self->redis_connection->zremrangebyrank($feed_id_items_hash_zset_key,
				                                 0, ($md5_zset_length - $max_items_in_feed));		
	}
	
	return @dead_items;
} 
#11
############################################
# Usage      : del_feed('http://some/tricky/url/here.cgi');
# Purpose    : delete feed from database
# Returns    : none
# Parameters : url string or feed id
# Throws     : no exceptions
# Comments   : ???
# See Also   : n/a
sub del_feed(){
	my ($self, $feed_identificator) = @_;
	my $feed_url = "";	
	my $feed_id;
	my $feed_id_url_key = '';
	my $feed_url_id_key = '';
	if($feed_identificator =~ /{d+}/xms){
		$feed_id = $feed_identificator;
		$feed_id_url_key = $self->get_filled_key('FEED_ID_URL', {"id" =>$feed_id});
		$feed_url = $self->redis_connection->get($feed_id_url_key);		
		$feed_url_id_key = $self->get_filled_key('FEED_URL_ID', {'url' => md5_hex($feed_url)});
		
	}else{
		$feed_url = $feed_identificator;
		$feed_url_id_key = $self->get_filled_key('FEED_URL_ID', {'url' => md5_hex($feed_url)});

		$feed_id = $self->redis_connection->get($feed_url_id_key);					
	}	
	$self->redis_connection->del($feed_url_id_key);
	
	my $feed_url_set_key = $self->get_filled_key('FEEDS_SET_URL', {});
	$self->redis_connection->srem($feed_url_set_key, $feed_url);
	
	my $feed_id_wild_key = $self->get_filled_key_wildcard('FEED_ID', {'id' => $feed_id});
	my @keys_to_del = $self->redis_connection->keys($feed_id_wild_key); 
	
	foreach my $key_to_del (@keys_to_del){
		$self->redis_connection->del($key_to_del);
	}	
}   
#12	
sub set_feed_title(){} #set title for the feed with given id
#13
sub get_feeds_id_title_map(){} #get hash pod_feed{id} = feed_title
	
	#'add_new_feed', #add feed url, title
#14 #check feed for url
############################################
# Usage      : $is_exists = is_feed_with_this_url_exists('http://some/tricky/url/here.cgi');
# Purpose    : check if the feed with the given url exists
# Returns    : true if exists, false otherwise
# Parameters : url string
# Throws     : no exceptions
# Comments   : ???
# See Also   : n/a
sub is_feed_with_this_url_exists(){
	my ($self, $url) = @_;
	
	my $feed_url_set_key = $self->get_filled_key('FEEDS_SET_URL', {});
	return $self->redis_connection->sismember($feed_url_set_key, $url);	
}  
#15	
sub set_new_podcast_item_ready_status(){}   #setst new podcast redines status
#16
sub get_new_podcast_item_ready_status(){} #get new podcast item ready status
#17	
sub add_pod_file_path_lable_to_podcast(){}
#18
sub get_user_podcast_files_paths(){} #return array of podcast files paths
#19	
sub get_user_podcast_files_lables(){} #return array of podcat files lables
#20
sub get_amount_of_user_podcast_files(){}
#21
sub del_user_podcast(){}
	
#22	
sub del_and_get_old_podcasts_from_podlist(){} #trimm old items from user podlist, and get all trimmed items
#23
sub get_podcast_last_check_time(){} #get last time, when user asks for this podcast
#24
sub set_podcast_last_check_time(){} #set time of last succesful feeds items getting
#25
sub get_users_feeds_new_items(){} #get new items for user feeds
#26	#add new user
############################################
# Usage      : add_new_user("user_login", "user_secret_password","user@email.em");
# Purpose    : add a new user inoo the system
# Returns    : status of operation true if succede
# Parameters : user login- string, user_password - string, user_email - string
# Throws     : no exceptions
# Comments   : ???
# See Also   : n/a
sub add_new_user(){
	my ($self, $login, $password, $email) = @_;
	
	my $users_next_id_key = $self->get_filled_key('USERS_NEXT_ID', {});	
	my $new_user_id = $self->redis_connection->incr($users_next_id_key);
	
	my $id_login_key = $self->get_filled_key('ID_LOGIN', {"login" => md5_hex($login)});
	my $set_ok = $self->redis_connection->set( $id_login_key, $new_user_id );
	
	my $user_id_login_key = $self->get_filled_key('USER_ID_LOGIN', {"id" => $new_user_id});
	$set_ok = $self->redis_connection->set( $user_id_login_key, $login );
	
	my $user_id_email_key = $self->get_filled_key('USER_ID_EMAIL', {"id" => $new_user_id});
	$set_ok = $self->redis_connection->set( $user_id_email_key, $email );
	
	my $user_id_pass_key = $self->get_filled_key('USER_ID_PASS', {"id" => $new_user_id});
	$set_ok = $self->redis_connection->set( $user_id_pass_key,  md5_hex($password) );
	
	my $status = 0;
	if($set_ok){
		$status = 1;
	}
	
	return $status;
}   
#27 #delete user
############################################
# Usage      : delete_user("user_login"); delete_user(11);
# Purpose    : delete user
# Returns    : status of operation true if succede
# Parameters : user login- string OR user id - int
# Throws     : no exceptions
# Comments   : ???
# See Also   : n/a
sub delete_user(){
	my ($self, $user_identificator) = @_;
	
	my $user_id = 0;
	my $user_login = "";
	my $id_login_key = "";
 	if($user_identificator =~ /{d+}/xms){
		$user_id = $user_identificator;
		my $user_id_login_key = $self->get_filled_key('USER_ID_LOGIN', {"id" => $user_id});
		$user_login = $self->redis_connection->get($user_id_login_key);
		$id_login_key = $self->get_filled_key('ID_LOGIN', {"login" => md5_hex($user_login)});		
	}else{
		$user_login = $user_identificator;
		my $id_login_key = $self->get_filled_key('ID_LOGIN', {"login" => md5_hex($user_login)});
		$user_id = $self->redis_connection->get($id_login_key);				
	}	
	$self->redis_connection->del($id_login_key);
	
	my $user_id_wild_key = $self->get_filled_key_wildcard('USER_ID', {'id' => $user_id});
	my @keys_to_del = $self->redis_connection->keys($user_id_wild_key); 
	
	foreach my $key_to_del (@keys_to_del){
		$self->redis_connection->del($key_to_del);
	}	
	
}    
#28 
############################################
# Usage      : $is_exists = is_user_exists("user_login"); delete_user(11);
# Purpose    : check if user with such login exists
# Returns    : true if user exists false otherwises
# Parameters : user login- string OR user id - int
# Throws     : no exceptions
# Comments   : ???
# See Also   : n/a
sub is_user_exists(){
	my ($self, $user_identificator) = @_;
	
	my $user_id = 0;
	my $user_login = "";
	my $id_login_key = "";
	if($user_identificator =~ /{d+}/xms){
		$user_id = $user_identificator;
		my $user_id_login_key = $self->get_filled_key('USER_ID_LOGIN', {"id" => $user_id});
		$user_login = $self->redis_connection->get($user_id_login_key);
		$id_login_key = $self->get_filled_key('ID_LOGIN', {"login" => md5_hex($user_login)});		
	}else{
		$user_login = $user_identificator;
		my $id_login_key = $self->get_filled_key('ID_LOGIN', {"login" => md5_hex($user_login)});
		$user_id = $self->redis_connection->get($id_login_key);				
	}
	
	my $user_exists = (defined $user_id && $user_id != 0 && !($user_login  eq "") ) ? 1 : 0;
	
	return $user_exists;
} 
#29
sub update_user_password(){}
#30
sub is_user_password_valid(){} #get password hash for user name
#31
sub update_user_email(){}
#32
sub get_user_email(){}     #get email for user name
#33	
sub add_user_podcast(){} #add podcast for username and podcast name
#34
sub add_feed_id_to_user_feeds(){} #add new feed to user list
	
	
#35	
sub get_user_podcasts_ids(){} #get list of all user podcasts
#36
sub get_user_podcasts_id_title_map(){} #get hash podcsast{id} = poscast_title
#37
sub get_user_podcasts_titles(){} #get list of podcast titles
#38
sub get_user_podcast_feeds_ids(){} #get all feeds that contained in the podcast
#39	
sub get_user_feeds_ids(){} #get user feeds ids
	
	
	
	
	
	
	
	
	#'set_user_feed_last_time_chek', #set user feed last time check
#40		
sub set_user_feed_last_checked_item_num(){} #set user's feed last checked item number
#41	 
sub add_feed_id_to_user_podcast(){} #add feed id to user podcast feed list
#42
sub del_user_feed(){} #delete feed from user feeds list
#43
sub del_feed_id_from_user_podcast(){} #del feed id from podcast
	

1;