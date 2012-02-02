package Rss2PodCTL;

use strict;
use warnings;

use base 'CGI::Application';

use CGI::Application::Plugin::Session;
use CGI::Application::Plugin::Authentication;
use CGI::Application::Plugin::Redirect;
use CGI::Application::Plugin::Stream;

use JSON;
use Redis;
use Digest::MD5 qw(md5 md5_hex md5_base64);

#use ManageUserPodcasts;
use RSS2POD::SecurityProc;

#check and validate feed
use LWP::Simple qw(get);
use XML::Feed;
use Feed::Find;

#use Lingua::DetectCharset;
#use Convert::Cyrillic;
###
use Sys::Syslog qw(:standard);
use CGI::Application::Plugin::Config::Simple;
use Encode;
use utf8;
use MIME::Base64;
use Time::HiRes qw(time);
use IO::Socket::INET;

#cgiapp_init run right before setup method
#I will put here some Session parameters
sub cgiapp_init() {
	my $self = shift;

	#Init configuration
	if ( defined $ENV{APP_HOME} ) {
		$self->config_file("$ENV{APP_HOME}/../config/rss2pod.conf");
	}
	else {
		$self->config_file("../config/rss2pod.conf");
	}

	#$self->config_file('../config/webapp.conf');

	#Session part=====================================================
	my $redis = Redis->new();    # server => '127.0.0.1:6379' );

	$self->session_config(
		CGI_SESSION_OPTIONS => [
			"driver:redis",
			$self->query,
			{
				Redis  => $redis,
				Expire => 60 * 60 * 24
			}
		],
		COOKIE_PARAMS => { -path => '/', },
		SEND_COOKIE   => 1,
	);

	#Server log part ################################################
	openlog( "WebRss", "pid,perror,nofatal", "local0" );
}

# Метод setup не  являеться  хуком  он  предназначен  для  конфигурирования
# конретного приложения и вызываеться вслед за хуком init в методе new
sub setup {
	my $self = shift;

	$self->run_modes(
		auth_set_feeds               => \&PH_auth_set_feeds,
		auth_add_podcast             => \&PH_add_podcast,
		auth_get_user_podcasts       => \&PH_get_user_podcasts,
		auth_get_single_pod_data     => \&PH_get_single_pod_data,
		auth_delete_single_pod_data  => \&PH_delete_single_pod_data,
		auth_get_user_feeds          => \&PH_get_user_feeds,
		auth_add_feed                => \&PH_add_feed,
		auth_add_rss_to_podcast      => \&PH_add_rss_to_podcast,
		auth_del_feed_from_user_list => \&PH_del_feed_from_user_list,
		auht_del_feed_from_podcast   => \&PH_del_feed_from_podcast,
		auth_get_podcast_file        => \&PH_get_podcast_file,
		auth_gen_podcast_file        => \&PH_generate_podcast_file,
		auth_get_user_profile        => \&PH_get_user_profile,
		auth_check_pod_complite      => \&PH_check_pod_complite,
		auth_get_old_pod_files_lables_json =>
		  \&PH_get_old_pod_files_lables_json,
		login    => \&PH_login_mode,
		AUTOLOAD => \&PH_autoload_mode
	);
	$self->start_mode("auth_set_feeds");
	if ( defined $ENV{APP_HOME} ) {
		$self->tmpl_path("$ENV{APP_HOME}/../html_templates/");
	}
	else {
		$self->tmpl_path("../html_templates/");
	}

	#$self->tmpl_path("$ENV{APP_HOME}/../html_templates/");

	# добавляем режим для ошибок
	$self->error_mode( \&on_error );

	#here is the authentiacation  parameters
	$self->authen->config(

		#DRIVER => [ 'Generic', { user1 => '123' } ],
		STORE => 'Session',

		#LOGOUT_RUNMODE => 'start',
		LOGIN_RUNMODE => 'login',

		#LOGIN_URL     => 'run_auth.cgi'
		#POST_LOGIN_RUNMODE => 'auth_test'
	);
	$self->authen->protected_runmodes(qr/^auth_/);

}

#sub cgiapp_prerun {
#	my $self = shift;
#
#	# Redirect to login, if necessary
#	unless ( $self->authen->is_authenticated ) {
#		$self->prerun_mode('login');
#	}
#}

sub PH_auth_set_feeds() {
	my $self = shift;

=garb	
	my $template = $self->load_tmpl("rss_to_pod.tmpl.html");
	$self->header_add( -Content_Type => 'text/html; charset=UTF-8' );
	return $template->output();
=cut

	my $frame_template = $self->load_tmpl("index.tmpl.html");
	$frame_template->param( APP_PAGE => 1, );

	$self->header_add( -Content_Type => 'text/html; charset=UTF-8' );
	return $frame_template->output();

}

sub PH_login_mode() {
	my $self = shift;
	return $self->redirect('run_auth.cgi');
}

sub on_error {

# первым параметром в любой режим передаеться ссылка на сам объект CAP
	my $self = shift;

# вторым параметром передаеться строка с ошибкой
	my $error = shift;

	# простой заголовок
	my $output = "<h2>Internal error:</h2>\n";

	# наша ошибка
	$output .= "<pre><code>$error</code></pre>";

	# и добавляем кое какую системную инфу
	$output .= $self->dump_html;
	return $output;
}

#For now the only subject of this function to add proper header to
#HTML response for it to use UTF-8 in right way.
#sub cgiapp_postrun {
#	my $self = shift;
#
## вторым параметром ссылка на уже сгенерированный контент
#	my $body_ref = shift;
#	$self->header_add( -Content_Type => 'text/html; charset=UTF-8' );
#}

#The page that will be returned if user will passwrong parameter;
sub PH_autoload_mode() {
	return 'This page does not exist. Sorry :(';
}

=header1
This function will create RSS sequence for user
Parameters:
$dbh - DBI handle
$user_name - user name for hoom we create pod sequence
$sequence_name - name for this sequence
$seq_place - place of this sequnce in User interface 
=cut

sub PH_add_podcast() {
	my $self         = shift;
	my $podcast_name = "";
	my $response     = "ok";
	$podcast_name = $self->query->param("podcast_name");

	my $redis     = Redis->new(encode=>undef);                #( server => '127.0.0.1:6379');
	my $user_name = $self->authen->username();
	my $user_name_md5 = md5_hex($user_name);
	my $user_id       = $redis->get("id:$user_name_md5");

	my $secProcObj = new RSS2POD::SecurityProc();
	$user_id = 0 unless $secProcObj->get_preg( $user_id, 'digit' );
	$podcast_name = $secProcObj->trim_too_long_string( $podcast_name, 100 );
	if ($user_id) {		
		$response = $self->add_podcast( $redis, $user_id, $podcast_name );
	}
	else {

		#ERROR no such user somthing wrong
		$response = "no_such_user";
	}
	$redis->quit();
	return $response;

}

sub add_podcast() {
	my ( $self, $redis, $user_id, $podcast_name ) = @_;
	my $response = "ok";
	if (
		!$redis->exists(
			"user:$user_id:pod:" . md5_hex($podcast_name) . ":id"
		)
	  )
	{

		#all ok we can proceed
		my $new_pod_id = $redis->incr("user:$user_id:pod:nexId");
		my $set_ok =
		  $redis->set( "user:$user_id:pod:" . md5_hex($podcast_name) . ":id",
			$new_pod_id );
		$set_ok =
		  $redis->zadd( "user:$user_id:pod:pod_zset", $new_pod_id,
			$podcast_name );		
		if ( !$set_ok ) {
			$response = "redis_error";
		}
	}
	else {

		#podcast with such name already exists
		$response = "podcast_already_exists";
	}
	return $response;

}

=head3
Get from database all information about user feeds and podcasts and return it throught JSON.
The return value is hash of this structure:
...
{pod_info:	    
		{	'first_pod_id':$pod_id
			pod_list: [$pod_id_1, $pod_id_2, $pod_id_5],
			$pod_id:{
				"pod_feeds":[],
				"name":"sdfsd",
				"name_base64":"c2Rmc2Q=\n"
			}
			.............................
			$pod_id:{
				"pod_feeds":[],
				"name":"sdfsd",
				"name_base64":"c2Rmc2Q=\n"
			}		
			
		}
 feeds_info: [list of feeds id's]	
 feeds_title_mapping:{
 	feed_id: feed_title,
 	.......................
 }
}
=cut

sub PH_get_user_profile() {
	my $self         = shift;
	my %user_profile = ();

	my $redis     = Redis->new(encode=>undef);                #( server => '127.0.0.1:6379');
	my $user_name = $self->authen->username();
	my $user_name_md5 = md5_hex($user_name);
	my $user_id       = $redis->get("id:$user_name_md5");

	if ($user_id) {
		if (   !$redis->exists("user:$user_id:pod:pod_zset")
			&& !$redis->exists("user:$user_id:feeds:feeds_id_zset") ){
				
			$self->generate_first_run_user_profile( $user_id, $redis );
		}

		my @pod_id_list = $self->get_user_pod_id_list( $user_id, $redis );
		my %podcasts_info = $self->get_user_podcasts_struct( $user_id, $redis );
		my @user_feeds_id_list =
		  $redis->zrange( "user:$user_id:feeds:feeds_id_zset", 0, -1 );
		my %feeds_title_mapping = $self->get_user_feeds_title_id_mapping(
			$user_id, \@user_feeds_id_list,
			$redis
		);
		
		$user_profile{'pod_list'}            = \@pod_id_list;
		$user_profile{'pod_info'}            = \%podcasts_info;
		$user_profile{'feeds_title_mapping'} = \%feeds_title_mapping;
		$user_profile{'feeds_list'}          = \@user_feeds_id_list;

	}
	else {
		syslog( 'info', "Aeccess violation can't enter as $user_name" );
	}
	my $json = JSON->new->utf8(0);
	my $json_pod_list = $json->encode( \%user_profile );
	
	$self->header_add( -Content_Type => 'text/html; charset=UTF-8' );
	$redis->quit();
	return $json_pod_list;
}

############################################
# Usage      : $self->get_user_pod_id_list($user_id, $redis);
# Purpose    : get list of ID's of user podcasts
# Returns    : list
# Parameters : digit - user Id, and handle to redis database connection
# Throws     : no exceptions
# Comments   : ???
# See Also   : n/a
sub get_user_pod_id_list() {
	my ( $self, $user_id, $redis ) = @_;

	my @pod_id_list;

	if ( $redis->exists("user:$user_id:pod:pod_zset") ) {
		my @podcasts_names_list =
		  $redis->zrange( "user:$user_id:pod:pod_zset", 0, -1 );
		foreach my $pod_name (@podcasts_names_list) {
			my $pod_id =
			  $redis->get( "user:$user_id:pod:" . md5_hex($pod_name) . ":id" );
			push( @pod_id_list, $pod_id );
		}
	}

	return @pod_id_list;
}

############################################
# Usage      : $self->get_user_podcasts_struct($user_id, $redis);
# Purpose    : get list of ID's of user podcasts
# Returns    : list
# Parameters : digit - user Id, and handle to redis database connection
# Throws     : no exceptions
# Comments   : ???
# See Also   : n/a
sub get_user_podcasts_struct() {
	my ( $self, $user_id, $redis ) = @_;
	my %podcasts_info;
	my @podcasts_names_list =
	  $redis->zrange( "user:$user_id:pod:pod_zset", 0, -1 );

	#Fill first podcast id field
	if ( @podcasts_names_list > 0 ) {
		my $pod_name = $podcasts_names_list[0];
		my $pod_id =
		  $redis->get( "user:$user_id:pod:" . md5_hex($pod_name) . ":id" );
		$podcasts_info{'first_pod_id'} = ($pod_id);
	}

	#Get pod name and pod feeds ids, amd get this stuff into hash
	my @pod_id_list = (); #store the order of all podcasts in youre installation
	foreach my $pod_name (@podcasts_names_list) {
		my $podname_decoded = $pod_name;
		utf8::decode($podname_decoded);
		my $pod_name_enc_dec->{'name'} = $podname_decoded;
		
		$pod_name_enc_dec->{'name_base64'} = encode_base64($pod_name);
		my $pod_id =
		  $redis->get( "user:$user_id:pod:" . md5_hex($pod_name) . ":id" );
		
		my @podcast_feeds_ids =
		  $redis->zrange( "user:$user_id:pod:$pod_id:rss_zset", 0, -1 );
		$pod_name_enc_dec->{'pod_feeds'} = \@podcast_feeds_ids;
		
		$podcasts_info{$pod_id} = $pod_name_enc_dec;
	}

	return %podcasts_info;
}

############################################
# Usage      : $self->get_user_feeds_title_id_mapping($user_id, \@feeds_id_list,$redis);
# Purpose    : return hash of feed_id => feed title
# Returns    : hash
# Parameters : digit - user Id, reference to feeds_ids_list,and handle to redis database connection
# Throws     : no exceptions
# Comments   : ???
# See Also   : n/a
sub get_user_feeds_title_id_mapping() {
	my ( $self, $user_id, $user_feeds_id_list_ref, $redis, ) = @_;

	my %feeds_title_mapping;
	foreach my $feed_id ( @{$user_feeds_id_list_ref} ) {
		my %feed_entity;
		my $feed_title = $redis->get("feed:$feed_id:title");
		if ( defined $feed_title ) {

			#$feed_title = encode( 'utf8', $feed_title );
		}
		else {
			$feed_title = $redis->get("feed:$feed_id:url");
		}
		$feeds_title_mapping{$feed_id} = $feed_title;
	}

	return %feeds_title_mapping;
}

=header3
if no user data presented, generate it and put into redis
=cut

sub generate_first_run_user_profile() {
	my ( $self, $user_id, $redis ) = @_;
	my %user_profile  = ();
	my %podcasts_info = ();

	if ( !$redis->exists("user:$user_id:pod:pod_zset") ) {

		#&& $redis->zcount("user:$user_id:pod:pod_zset", "-inf", "+inf") == 0
		my $podcast_name = "Your first podcast";
		$self->add_podcast( $redis, $user_id, $podcast_name );
	}

	unless ( $redis->exists("user:$user_id:feeds:feeds_id_zset") ) {
		my $feed_url   = "http://rss2pod.urbancamper.ru/my_rss.xml";
		my $feed_title = "Youre first feed";

		$self->add_feed_to_database( $redis, $feed_url, $feed_title );
		$self->add_feed_to_user_list( $redis, $user_id, $feed_url );
	}
}

=header1
Get all user podcast and send json array as answer
=cut

sub PH_get_user_podcasts() {
	my $self          = shift;
	my @podcasts_list = ();

	my $redis     = Redis->new();                #( server => '127.0.0.1:6379');
	my $user_name = $self->authen->username();
	my $user_name_md5 = md5_hex($user_name);
	my $user_id       = $redis->get("id:$user_name_md5");

	if ( defined $user_id ) {
		if ( $redis->exists("user:$user_id:pod:pod_zset") ) {

			#all ok we can proceed
			#my $pod_list_len = $redis->llen("user:$user_id:pod:pod_list");
			my @podcasts_names_list =
			  $redis->zrange( "user:$user_id:pod:pod_zset", 0, -1 );
			foreach my $podname (@podcasts_names_list) {
				my $pod_name_enc_dec->{'name'} = encode_utf8($podname);
				$pod_name_enc_dec->{'name_base64'} =
				  encode_base64( encode_utf8($podname) );
				push( @podcasts_list, $pod_name_enc_dec );
			}
		}
		else {

			#podcast with such name already exists
			#$response = "podcast_already_exists";
		}
	}
	else {

		#ERROR no such user somthing wrong
		#$response="no_such_user";
	}

	my $json = JSON->new->allow_nonref;

	#$json = $json->utf8(1);
	my $json_pod_list = $json->encode( \@podcasts_list );
	$self->header_add( -Content_Type => 'text/html; charset=UTF-8' );
	$redis->quit();
	return $json_pod_list;
}

=header1
This function delete pod sequence 
Parameters:
$dbh - DBI handle
$user_name - user name for hoom we create pod sequence
$sequence_name - name for this sequence
$seq_place - place of this sequnce in User interface 
=cut

sub PH_get_single_pod_data() {
	my $self         = shift;
	my %podcast_info = ();

	my $redis     = Redis->new();                #( server => '127.0.0.1:6379');
	my $user_name = $self->authen->username();
	my $user_name_md5   = md5_hex($user_name);
	my $user_id         = $redis->get("id:$user_name_md5");
	my $pod_name_base64 = $self->query->param("pod_name_base64");

	if ($user_id) {
		if ( $redis->exists("user:$user_id:pod:pod_zset") ) {
			syslog( 'info', "Get info for $pod_name_base64 " );

			#all ok we can proceed
			#my @podcast_name =
			#  $redis->zrange( "user:$user_id:pod:pod_zset", 0, -1 );
			#$podcast_info{"pod_name"} = $podcast_name[$pod_index_in_list];
			$podcast_info{"pod_name"} = decode_base64($pod_name_base64);
			my $pod_id =
			  $redis->get( "user:$user_id:pod:"
				  . md5_hex( $podcast_info{"pod_name"} )
				  . ":id " );
			
			my @podcast_feeds_ids =
			  $redis->zrange( "user:$user_id:pod:$pod_id:rss_zset", 0, -1 );
			
			my @podcast_feeds_url;

			foreach my $feed_id (@podcast_feeds_ids) {
				my %feed_entity;
				my $feed_title = $redis->get("feed:$feed_id:title");
				if ( defined $feed_title ) {

					#push( @user_feeds_list, encode( 'utf8', $feed_title ) );
					$feed_title = encode( 'utf8', $feed_title );
				}
				else {
					$feed_title = $redis->get("feed:$feed_id:url");

					#push( @user_feeds_list, $feed_url );
				}
				$feed_entity{'title'} = $feed_title;
				$feed_entity{'id'}    = $feed_id;
				push( @podcast_feeds_url, \%feed_entity );
			}
			if ( @podcast_feeds_url > 0 ) {
				$podcast_info{"pod_feeds"} = \@podcast_feeds_url;
			}

		}
		else {

			#podcast with such name already exists
			#$response = "podcast_already_exists";
		}
	}
	else {

		#ERROR no such user somthing wrong
		#$response="no_such_user";
	}

	my $json = JSON->new->allow_nonref;

	my $json_pod_list = $json->encode( \%podcast_info );
	$redis->quit();
	$self->header_add( -Content_Type => 'text/html; charset=UTF-8' );
	return $json_pod_list;
}

=header1
This function delete pod sequence 
Parameters:
$dbh - DBI handle
$user_name - user name for hoom we create pod sequence
$sequence_name - name for this sequence
$seq_place - place of this sequnce in User interface 
=cut

sub PH_delete_single_pod_data() {
	my $self         = shift;
	my %podcast_info = ();

	my $redis     = Redis->new();                #( server => '127.0.0.1:6379');
	my $user_name = $self->authen->username();
	my $user_name_md5   = md5_hex($user_name);
	my $user_id         = $redis->get("id:$user_name_md5");
	my $pod_name_pase64 = $self->query->param("pod_name_pase64");
	my $pod_name        = decode_base64($pod_name_pase64);

	my $success_return = "ok";

	if ($user_id) {
		if ( $redis->exists("user:$user_id:pod:pod_zset") ) {
			my $pod_id =
			  $redis->get( "user:$user_id:pod:" . md5_hex($pod_name) . ":id" );

	   #delete podcast info
	   #get last name from pod names, than put it in pod_list enstead of last el

			my $ok_del_from_list =
			  $redis->zrem( "user:$user_id:pod:pod_zset", $pod_name );
			my $ok_del =
			  $redis->del( "user:$user_id:pod:" . md5_hex($pod_name) . ":id" );
			$ok_del = $redis->del("user:$user_id:pod:$pod_id:rss_zset");
			$ok_del = $redis->del("user:$user_id:pod:$pod_id:rss_nextId");
			$ok_del = $redis->del("user:$user_id:pod:$pod_id:last_chk_time");
			$ok_del = $redis->del("user:$user_id:pod:$pod_id:gen_mp3_stat");
			
			###delete all podcast files###################################
			if ( $redis->exists("user:$user_id:pod:$pod_id:pod_files_names") ) {
				my $json = JSON->new->allow_nonref;
				while ( my $file_struct_json =
					$redis->lpop("user:$user_id:pod:$pod_id:pod_files_names") )
				{
					my $file_struct = $json->decode($file_struct_json);
					unlink $file_struct->{"file_path"};
				}
			}
			#######then delete filed in redis################################
			$ok_del = $redis->del("user:$user_id:pod:$pod_id:pod_files_names");
		}
		else {
			$success_return = "error can't find user:$user_id:pod:pod_list";
		}
	}
	else {
		$success_return = "error";
	}
	$redis->quit();
	$self->header_add( -Content_Type => 'text/html; charset=UTF-8' );
	return $success_return;
}

=head3
Add feed url and title to database
Param: $feed_url - URI of feed
$feed_title - Title of feed
=cut

sub add_feed_to_database() {
	my ( $self, $redis, $feed_url, $feed_title ) = @_;

	my $redis_ok = "ok";
	unless ( $redis->sismember( "feeds:set:url", $feed_url ) ) {
		$redis_ok = $redis->sadd( "feeds:set:url", $feed_url );
		my $feed_id = $redis->incr("feed:nextId");
		if ($feed_id) {
			$redis_ok = $redis->set( "feed:$feed_id:url", $feed_url );
			$redis_ok =
			  $redis->set( "feed:" . md5_hex($feed_url) . ":id", $feed_id );
			if ( defined $feed_title ) {
				$redis_ok = $redis->set( "feed:$feed_id:title", $feed_title );
			}
		}

	   #add feed to the queue of feeds that need to be added to the work process
		$redis_ok = $redis->sadd( "feeds:addurlqueue:set", $feed_url );
	}

	return $redis_ok;
}

=head3
Add info about feeds into user list of feeds
=cut

sub add_feed_to_user_list() {
	my ( $self, $redis, $user_id, $feed_url ) = @_;

	#manage user feed list
	my $feed_id  = $redis->get( "feed:" . md5_hex($feed_url) . ":id" );
	my $redis_ok = "1";
	if ($feed_id) {
		$redis_ok =
		  $redis->zscore( "user:$user_id:feeds:feeds_id_zset", $feed_id );
		unless ($redis_ok) {
			my $user_feed_id = $redis->incr("user:$user_id:feeds:nextId");
			$redis_ok = $redis->zadd( "user:$user_id:feeds:feeds_id_zset",
				$user_feed_id, $feed_id );  #add id of feed into user feeds zset
			    #the following command means that this feed was never checked
			$redis_ok =
			  $redis->set( "user:$user_id:feeds:$feed_id:last_chk", 0 );
		}
	}
	return $redis_ok;
}

=head1
This function adds new RSS URL into list of rsses
=cut

sub PH_add_feed() {
	my $self         = shift;
	my %podcast_info = ();

	my $redis     = Redis->new();                #( server => '127.0.0.1:6379');
	my $user_name = $self->authen->username();
	my $user_name_md5 = md5_hex($user_name);
	my $user_id       = $redis->get("id:$user_name_md5");
	my $feed_url      = $self->query->param("feed_url");

	my $sec_proc_obj = new RSS2POD::SecurityProc();
	$feed_url = $sec_proc_obj->trim_too_long_string( $feed_url, 300 );

	my $success_return = "ok";

	my $redis_ok = "1";
	if ($user_id) {

	 #check if this feed already in our feeds list and if so add it to user list
		my $is_feed_exists = $redis->sismember( "feeds:set:url", $feed_url );
		if ($is_feed_exists) {
			$redis_ok =
			  $self->add_feed_to_user_list( $redis, $user_id, $feed_url );
			if ( !$redis_ok ) {
				$success_return = "error in database";
			}
		}
		else {

#check if this feed is available, and try to fetch all feeds from user given list
			my $feed_url_valid_result =
			  $self->check_feed_availability($feed_url);
			if ( $feed_url_valid_result->{'status'} eq "ok" ) {
				foreach
				  my $feed_info ( @{ $feed_url_valid_result->{'feeds_info'} } )
				{
					my $feed_url   = $feed_info->{'url'};
					my $feed_title = $feed_info->{'title'};

				 #check if this feed already in our feeds list and if not add it
				 #return flag of adding operation
					$redis_ok =
					  $self->add_feed_to_database( $redis, $feed_url,
						$feed_title );
					if ($redis_ok) {
						$self->add_feed_to_user_list( $redis, $user_id,
							$feed_url );
					}
					else {
						$success_return = "error in database";
						syslog( 'err',
							"Error in database during new feed adding" );
					}
				}
			}
			else {
				$success_return = "url_is_not_available";
			}
		}
	}
	else {
		$success_return = "no_such_user";
	}
	unless ($redis_ok) {
		$success_return = "database_error";
	}
	$redis->quit();
	return $success_return;
}

=header1
Get all user podcast and send json array as answer
=cut

sub PH_get_user_feeds() {
	my $self = shift;
	my %user_feeds_info;

	my $redis     = Redis->new();                #( server => '127.0.0.1:6379');
	my $user_name = $self->authen->username();
	my $user_name_md5 = md5_hex($user_name);
	my $user_id       = $redis->get("id:$user_name_md5");

	if ($user_id) {
		if ( $redis->exists("user:$user_id:feeds:feeds_id_zset") ) {
			my @user_feeds_id_list =
			  $redis->zrange( "user:$user_id:feeds:feeds_id_zset", 0, -1 );
			my %feeds_title_mapping;
			foreach my $feed_id (@user_feeds_id_list) {
				my %feed_entity;
				my $feed_title = $redis->get("feed:$feed_id:title");
				if ( defined $feed_title ) {
					$feed_title = encode( 'utf8', $feed_title );
				}
				else {
					$feed_title = $redis->get("feed:$feed_id:url");
				}
				$feeds_title_mapping{$feed_id} = $feed_title;
			}
			$user_feeds_info{'feeds_title_mapping'} = \%feeds_title_mapping;
			$user_feeds_info{'feeds_list'}          = \@user_feeds_id_list;
		}
		else {
			syslog( 'err',
"Error in redis access. Can't find key user:$user_id:feeds:feeds_id_zset"
			);
		}
	}
	else {
		syslog( 'info', "Aeccess violation can't enter as $user_name" );
	}

	my $json = JSON->new->allow_nonref;

	#$json = $json->utf8(1);
	my $json_feeds_list = $json->encode( \%user_feeds_info );
	$redis->quit();
	$self->header_add( -Content_Type => 'text/html; charset=UTF-8' );
	return $json_feeds_list;
}

=head1
This function add rss into podcast
=cut

sub PH_add_rss_to_podcast() {
	my $self         = shift;
	my %podcast_info = ();

	my $redis     = Redis->new();                #( server => '127.0.0.1:6379');
	my $user_name = $self->authen->username();
	my $user_name_md5 = md5_hex($user_name);
	my $user_id       = $redis->get("id:$user_name_md5");

	#get id of rss from list of all rssess of user
	my $feed_id = $self->query->param("feed_id");
	my $pod_id  = $self->query->param("pod_id");

	my $sec_proc_obj = new RSS2POD::SecurityProc();
	$feed_id = 0 unless $sec_proc_obj->get_preg( $feed_id, 'digit' );
	$pod_id  = 0 unless $sec_proc_obj->get_preg( $pod_id,  'digit' );
	$feed_id = $sec_proc_obj->trim_too_long_string( $feed_id, 10 );
	$pod_id  = $sec_proc_obj->trim_too_long_string( $pod_id,  10 );

	my $success_return = "ok";
	my $redis_ok;
	if ($user_id) {
		if ( $redis->exists("user:$user_id:pod:pod_zset") ) {

			#add this id to pod rss zset
			my $new_id_for_feed_in_pod =
			  $redis->incr("user:$user_id:pod:$pod_id:rss_nextId");

			if ( $redis->get("feed:$feed_id:url") ) {
				my $nil_score =
				  $redis->zscore( "user:$user_id:pod:$pod_id:rss_zset",
					$feed_id );
				if ( !$nil_score ) {
					$redis_ok =
					  $redis->zadd( "user:$user_id:pod:$pod_id:rss_zset",
						$new_id_for_feed_in_pod, $feed_id );
					if ( !$redis_ok ) {
						$success_return = "error";
					}
				}
			}

		}
	}
	else {
		$success_return = "error";
	}
	$redis->quit();
	return $success_return;

}

=head1
this function delete rss feed from user list, also this function will 
delete this feed from all podcasts.
=cut

sub PH_del_feed_from_user_list() {
	my $self         = shift;
	my %podcast_info = ();

	my $redis     = Redis->new();                #( server => '127.0.0.1:6379');
	my $user_name = $self->authen->username();
	my $user_name_md5 = md5_hex($user_name);
	my $user_id       = $redis->get("id:$user_name_md5");
	my $feed_id       = $self->query->param("feed_id");

	my $sec_proc_obj = new RSS2POD::SecurityProc();
	$feed_id = 0 unless $sec_proc_obj->get_preg( $feed_id, 'digit' );
	$feed_id = $sec_proc_obj->trim_too_long_string( $feed_id, 10 );

	my $success_return = "ok";
	my $redis_ok;
	if ($user_id) {
		if ( $redis->exists("user:$user_id:feeds:feeds_id_zset") ) {
			my $is_deleted =
			  $redis->zrem( "user:$user_id:feeds:feeds_id_zset", $feed_id );
			$is_deleted = $redis->del("user:$user_id:feeds:$feed_id:last_chk");

			unless ($is_deleted) {
				$success_return = "error";
			}
		}
	}
	else {
		$success_return = "error";
	}
	$redis->quit();
	return $success_return;
}

=head1
this function delete rss feed from podcast
=cut

sub PH_del_feed_from_podcast() {
	my $self         = shift;
	my %podcast_info = ();

	my $redis     = Redis->new();                #( server => '127.0.0.1:6379');
	my $user_name = $self->authen->username();
	my $user_name_md5 = md5_hex($user_name);
	my $user_id       = $redis->get("id:$user_name_md5");

	#get id of rss from list of all rssess of user
	my $feed_id = $self->query->param("feed_id");
	my $pod_id  = $self->query->param("pod_id");

	my $sec_proc_obj = new RSS2POD::SecurityProc();
	$feed_id = 0 unless $sec_proc_obj->get_preg( $feed_id, 'digit' );
	$pod_id  = 0 unless $sec_proc_obj->get_preg( $pod_id,  'digit' );
	$feed_id = $sec_proc_obj->trim_too_long_string( $feed_id, 10 );
	$pod_id  = $sec_proc_obj->trim_too_long_string( $pod_id,  10 );

	my $success_return = "ok";
	my $redis_ok;
	if ($user_id) {
		if ( $redis->exists("user:$user_id:pod:pod_zset") ) {
			
			my $redis_ok =
			  $redis->zrem( "user:$user_id:pod:$pod_id:rss_zset", $feed_id );
			if ( !$redis_ok ) {
				$success_return = "error";
				syslog( 'err',
					"Cant delete $feed_id from $pod_id for $user_id" );
			}
		}
	}
	else {
		$success_return = "error";
	}
	$redis->quit();
	return $success_return;
}


sub PH_check_pod_complite() {
	my $self      = shift;
	my $redis     = Redis->new();                #( server => '127.0.0.1:6379');
	my $user_name = $self->authen->username();
	my $user_name_md5 = md5_hex($user_name);
	my $user_id       = $redis->get("id:$user_name_md5");
	my $pod_id        = $self->query->param("pod_id");
	my $current_time  = time();

	my $sec_proc_obj = new RSS2POD::SecurityProc();
	$pod_id = 0 unless $sec_proc_obj->get_preg( $pod_id, 'digit' );
	$pod_id = $sec_proc_obj->trim_too_long_string( $pod_id, 10 );

#nothing, in future this should be changed to empty mp3 with some noise about donation
	my $response = "ok";
	if ($user_id) {
		if ( $redis->exists("user:$user_id:pod:$pod_id:gen_mp3_stat") ) {
			my $stat = $redis->get("user:$user_id:pod:$pod_id:gen_mp3_stat");
			if (   $stat eq "ok"
				|| $stat eq "empty_file"
				|| $stat eq "internal_error" )
			{
				$response = $stat;
			}
			else {
				$response = "whait";
			}

		}
		else {
			$response = "internall_error";
		}
	}
	else {

		#ERROR no such user somthing wrong
		$response = "no_such_user";
	}
	$redis->quit();
	return $response;

}

=head3
Get name of podcast file from REDIS databaser read this file and send content to user
=cut

sub PH_get_podcast_file() {
	my $self      = shift;
	my $redis     = Redis->new();                #( server => '127.0.0.1:6379');
	my $user_name = $self->authen->username();
	my $user_name_md5 = md5_hex($user_name);
	my $user_id       = $redis->get("id:$user_name_md5");
	my $pod_id        = $self->query->param("pod_id");
	my $old_pod_num   = $self->query->param("old_pod_num");

	$pod_id      = 0 unless defined $pod_id;
	$old_pod_num = 0 unless defined $old_pod_num;

	my $sec_proc_obj = new RSS2POD::SecurityProc();
	$old_pod_num = 0 unless $sec_proc_obj->get_preg( $old_pod_num, 'digit' );
	$pod_id      = 0 unless $sec_proc_obj->get_preg( $pod_id,      'digit' );
	$old_pod_num = $sec_proc_obj->trim_too_long_string( $old_pod_num, 10 );
	$pod_id      = $sec_proc_obj->trim_too_long_string( $pod_id,      10 );
	

	my $current_time = time();

#nothing, in future this should be changed to empty mp3 with some noise about donation
	my $mp3_output = "";
	my $file_name  = "rss2pod_none.mp3";
	if ($user_id) {

		if ( $redis->exists("user:$user_id:pod:$pod_id:pod_files_names") ) {
			my @out_files_json =
			  $redis->lrange( "user:$user_id:pod:$pod_id:pod_files_names",
				-1 * $self->config_param("general.max_podcasts_user_files"),
				-1 );

			#syslog( 'info', "Get tts file: $out_files_json[0]" );
			if (@out_files_json) {
				my $json = JSON->new->allow_nonref;
				my $out_file_json =
				  $out_files_json[ $#out_files_json - $old_pod_num ]
				  ;    #$out_files_json[0];
				my $file_struct = $json->decode($out_file_json);
				$file_name = $self->gen_podcast_file_name($user_id, $pod_id, $file_struct->{"file_path"});
				    
				my $out_file_handle;
				open $out_file_handle, $file_struct->{"file_path"};
				binmode $out_file_handle;
				my ( $data, $n );

				while ( ( $n = read $out_file_handle, $data, 1024 ) != 0 ) {
					$mp3_output .= $data;
				}
				close($out_file_handle);
			}
		}
		else {
			$mp3_output = "";
		}
	}
	
	use bytes;
	my $mp3_len = length($mp3_output);
	no bytes;
	$self->header_add( -Content_Type => 'audio/mpeg' );
	$self->header_add(
		-Content_Disposition => "attachment;filename=$file_name" );
	$self->header_add(
		-Content_Length  => $mp3_len,
		-Content_Expires => '+3d',
	);
	$redis->quit();
	return $mp3_output;

}

############################################
# Usage      : $self->gen_podcast_file_name($user_id, $pod_id, $file_puth);
# Purpose    : Create podcast file name  for user
# Returns    : string with file name
# Parameters : user id, podcast id, file_path from file_struct
# Throws     : no exceptions
# Comments   : File path can be substituted by every string unic for
#every file of podcasts for this user
# See Also   : n/a
sub gen_podcast_file_name(){
	my ($self, $user_id, $pod_id, $file_path) = @_;
	my $file_name = "rss2pod_"
				  . md5_hex( $user_id . $pod_id . $file_path )
				  . ".mp3";
	return $file_name;			 
}


=head3
Get json struct of for stored pods
[0: { datatime: '$user_datatime'}
 1: {...}	
]
=cut

sub PH_get_old_pod_files_lables_json() {
	my $self      = shift;
	my $redis     = Redis->new();                #( server => '127.0.0.1:6379');
	my $user_name = $self->authen->username();
	my $user_name_md5 = md5_hex($user_name);
	my $user_id       = $redis->get("id:$user_name_md5");
	my $pod_id        = $self->query->param("pod_id");

	my $sec_proc_obj = new RSS2POD::SecurityProc();
	$pod_id = 0 unless $sec_proc_obj->get_preg( $pod_id, 'digit' );
	$pod_id = $sec_proc_obj->trim_too_long_string( $pod_id, 10 );

	my $json       = JSON->new->allow_nonref;
	my @pod_lables = ();

	if ($user_id) {
		my @old_podcats;
		if ( $redis->exists("user:$user_id:pod:$pod_id:pod_files_names") ) {
			@old_podcats =
			  $redis->lrange( "user:$user_id:pod:$pod_id:pod_files_names",
				-1 * $self->config_param("general.max_podcasts_user_files"),
				-1 );
			foreach my $pod_path_lable_json (@old_podcats) {
				my $pod_path_lable = $json->decode($pod_path_lable_json);
				my $pod_lable      = $pod_path_lable->{datatime};
				push @pod_lables, $pod_lable;
			}
		}

	}
	
	my $pod_lables_json = $json->encode( \@pod_lables );
	$redis->quit();
	return $pod_lables_json;
}

sub get_amount_of_stored_pod_files() {
	my ( $self, $redis, $pod_id ) = @_;

	my $user_name     = $self->authen->username();
	my $user_name_md5 = md5_hex($user_name);
	my $user_id       = $redis->get("id:$user_name_md5");

	
	my $ammount_of_stored_files = 0;
	if ($user_id) {
		if ( $redis->exists("user:$user_id:pod:$pod_id:pod_files_names") ) {
			$ammount_of_stored_files =
			  $redis->llen("user:$user_id:pod:$pod_id:pod_files_names");
		}
	}	
	return $ammount_of_stored_files;
}

sub send_data_to_gen_pod_daemon() {
	my ( $self, $user_id, $pod_id, $user_datatime, $current_time ) = @_;
	my $is_send = 1;
	my $socket  = IO::Socket::INET->new(
		PeerAddr => $self->config_param("general.pod_gen_host"),
		PeerPort => $self->config_param("general.pod_gen_port"),
		Proto    => "tcp",
		Type     => SOCK_STREAM
	);
	unless ( defined $socket ) {
		syslog( 'err',
			    "cant establish connection to PodGeneratorDaemon on "
			  . $self->config_param("general.pod_gen_host") . ":"
			  . $self->config_param("general.pod_gen_port") );
		$is_send = "0";
	}
	else {
		my $flags;
		$socket->send( "Hello\n", $flags );

		my $data_to_read;
		$data_to_read = <$socket>;
		syslog( "info", "Start protocol with $data_to_read" );
		if (   defined $user_id
			&& defined $pod_id
			&& defined $current_time )
		{
			print $socket "$user_id\n";
			print $socket "$pod_id\n";
			print $socket "$current_time\n";
			print $socket "$user_datatime\n";
		}
		$data_to_read = <$socket>;
		syslog( "info", "Stop protocol with $data_to_read" );
		$socket->close();
	}
	return $is_send;
}

=head3
Create podcast file end send it as answer.
=cut

sub PH_generate_podcast_file() {
	my $self = shift;

	my $redis     = Redis->new();                #( server => '127.0.0.1:6379');
	my $user_name = $self->authen->username();
	my $user_name_md5 = md5_hex($user_name);
	my $user_id       = $redis->get("id:$user_name_md5");
	my $pod_id        = $self->query->param("pod_id");
	my $user_datatime = $self->query->param("datatime");

	my $sec_proc_obj = new RSS2POD::SecurityProc();
	$pod_id = 0 unless $sec_proc_obj->get_preg( $pod_id, 'digit' );
	$user_datatime = $sec_proc_obj->trim_too_long_string( $user_datatime, 100 );
	$pod_id        = $sec_proc_obj->trim_too_long_string( $pod_id,        10 );

	my $current_time = time();
	my $pod_last_chk_time =
	  $redis->get("user:$user_id:pod:$pod_id:last_chk_time");
	$pod_last_chk_time = 0 unless defined $pod_last_chk_time;

#nothing, in future this should be changed to empty mp3 with some noise about donation
	my $response = "ok";
	if ($user_id) {
		my $is_send =
		  $self->send_data_to_gen_pod_daemon( $user_id, $pod_id, $user_datatime,
			$current_time );
		unless ($is_send) {
			$response = "internal_error";
		}
		else {
			$redis->set( "user:$user_id:pod:$pod_id:gen_mp3_stat", "init" );
		}
	}
	else {

		#ERROR no such user somthing wrong
		$response = "no_such_user";
	}

	$redis->quit();
	return $response;
}

=head3 check_feed_availability
Check if url is built on top of template http://__user_url.
Than check if this url is available 
Return "ok" if all constrains is ok
"not_valid_url" if url is not conform template pattern
and "url_not_available" if url is not avalable
TO DO: Add check conditions for nor rss url case
=cut

sub check_feed_availability() {
	my ( $self, $url ) = @_;

	my $availability_stat->{'status'} = "ok";

	my @found_feeds = XML::Feed->find_feeds($url);
	my @feeds_info  = ();
	foreach my $furl (@found_feeds) {
		my $single_feed->{'url'} = $furl;
		my $feed_parsed;
		eval { $feed_parsed = XML::Feed->parse( URI->new($furl) ); };
		if ($feed_parsed) {
			my $feed_title = $feed_parsed->title;

			if ( defined $feed_title && !( $feed_title eq "" ) ) {				
				$single_feed->{'title'} = $feed_title;
			}
			
			syslog( 'info',
				"Add $furl into list of feeds for adding into database" );
			push( @feeds_info, $single_feed );
		}

	}
	$availability_stat->{'feeds_info'} = \@feeds_info;
	if ( @found_feeds == 0 || @feeds_info == 0 ) {
		$availability_stat->{'status'} = "url_not_available";
	}
	return $availability_stat;
}

1;
