package RSS2POD::DB::DBRedis;

use Moose;
use Redis;

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

1;