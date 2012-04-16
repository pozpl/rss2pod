package RSS2POD::DB::DBAccessFuncs;
use strict;
use warnings;
use Moose::Role;

requires (
	'get_feeds_urls', #get all feeds urls from a database and retun it as an array
	 
	'get_and_del_feed_url_from_queue_of_new_feeds', #get feed url from queue of new feeds that we need to add to downloading process
	'add_feed_url_to_queue_of_new_feeds', #add feed url to download queue
	
	'add_feed_item_to_voicefy_queue', #add item to voicefy queue
	'get_and_del_feed_item_from_voicefy_queue', #get feed item and delete it from queue
	
	'add_item_to_feed', #add item to current feed
	'is_item_alrady_in_feed', #check presence of given item in given feed
	
	'create_feed_for_url', #add feed into system for given url
	'get_feed_id_for_url', #receive feed url and get feed id for this feed if it exists
	'del_and_get_old_items_from_feed',#trim feed items list, and get all trimmed entities
	'del_feed', #delete feed from database, it support even URL or feed ID
	'set_feed_title', #set title for the feed with given id
	'get_feeds_id_title_map', #get hash pod_feed{id} = feed_title
	#'add_new_feed', #add feed url, title
	'is_feed_with_this_url_exists', #check feed for url
	
	'set_new_podcast_item_ready_status',#setst new podcast redines status
	'get_new_podcast_item_ready_status',#get new podcast item ready status
	
	'add_pod_file_path_lable_to_podcast',
	'get_user_podcast_files_paths', #return array of podcast files paths
	'get_user_podcast_files_lables', #return array of podcat files lables
	'get_amount_of_user_podcast_files',
	'del_user_podcast',#
	
	
	'del_and_get_old_podcasts_from_podlist',#trimm old items from user podlist, and get all trimmed items
	'get_podcast_last_check_time', #get last time, when user asks for this podcast
	'set_podcast_last_check_time',#set time of last succesful feeds items getting
	'get_users_feeds_new_items', #get new items for user feeds
	
	'add_new_user', #add new user
	'delete_user', #delete user
	'is_user_exists',#check if user with such login exists
	'update_user_password',
	'is_user_password_valid',#get password hash for user name
	'update_user_email',
	'get_user_email',#get email for user name
	
	'add_user_podcast', #add podcast for username and podcast name
	'add_feed_id_to_user_feeds', #add new feed to user list
	
	
	
	'get_user_podcasts_ids', #get list of all user podcasts
	'get_user_podcasts_id_title_map', #get hash podcsast{id} = poscast_title
	'get_user_podcasts_titles', #get list of podcast titles
	'get_user_podcast_feeds_ids', #get all feeds that contained in the podcast	
	'get_user_feeds_ids', #get user feeds ids
	
	
	
	
	
	
	
	
	#'set_user_feed_last_time_chek', #set user feed last time check	
	'set_user_feed_last_checked_item_num',#set user's feed last checked item number
	 
	'add_feed_id_to_user_podcast', #add feed id to user podcast feed list
	'del_user_feed', #delete feed from user feeds list
	'del_feed_id_from_user_podcast', #del feed id from podcast
	
		 
);


1;