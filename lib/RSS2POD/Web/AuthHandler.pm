package AuthHandler;

use strict;
use warnings;
use Env;


use base 'CGI::Application';
#use base 'CGI::Application::FastCGI';
use CGI::Application::Plugin::Session;
use CGI::Application::Plugin::Authentication;
use CGI::Application::Plugin::Redirect;
#use CGI::Application::Plugin::DBH (qw/dbh_config dbh/);
use Digest::MD5 qw(md5 md5_hex md5_base64);
use SecurityProc;
use Redis;
#use Redis::hiredis;
use CGI::Application::Plugin::CAPTCHA;

#cgiapp_init run right before setup method
#I will put here some DBH,Session parameters

sub cgiapp_init() {
	my $self = shift;

	#session part===================================================
	#Init new Redis object, to store session information within
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

	#$self->session_config(
	#	CGI_SESSION_OPTIONS => [
	#		"driver:File;serializer:default;id:md5", $self->query,
	#		{ Directory => '/tmp' }
	#	],
	#	COOKIE_PARAMS => { -path => '/', },
	#	SEND_COOKIE   => 1,
	#);

}

# Метод setup не  являеться  хуком  он  предназначен  для  конфигурирования
# конретного приложения и вызываеться вслед за хуком init в методе new
sub setup {
	my $self = shift;

	$self->run_modes(
		start           => \&login_mode,
		login           => \&login_mode,
		start_reg       => \&register_init,
		register        => \&register,
		auth_test       => \&auth_test,
		AUTOLOAD        => \&autoload_mode,
		get_reg_captcha => \&get_reg_captcha,
		logout          => \&logout
	);

	if(defined $ENV{APP_HOME}){
		$self->tmpl_path("$ENV{APP_HOME}/../html_templates/");
	}else{
		$self->tmpl_path("../html_templates/");
	}
	#$self->tmpl_path("$ENV{APP_HOME}/../html_templates/");

	# добавляем режим для ошибок
	$self->error_mode( \&on_error );

	#here is the authentiacation  parameters
	$self->authen->config(
		DRIVER => [ 'Generic', \&password_check ],

		#DRIVER => [
		#	'DBI',
		#	DBH         => $self->dbh,
		#	TABLE       => 'users',
		#	CONSTRAINTS => {
		#		'users.user_login'         => '__CREDENTIAL_1__',
		#		'md5_hex:users.user_password' => '__CREDENTIAL_2__'
		#	},
		#],
		LOGIN_FORM => { REGISTER_URL => 'run_auth.cgi?rm=start_reg' },
		STORE      => 'Session',

		#LOGOUT_RUNMODE => 'start',
		LOGIN_RUNMODE      => 'login',
		POST_LOGIN_RUNMODE => 'auth_test'
	);
	$self->authen->protected_runmodes(qr/^auth_/);

	$self->captcha_config(
		IMAGE_OPTIONS => {
			width  => 140,
			height => 60,
			lines  => 2,

			#font    => "/usr/share/fonts/TTF/luximb.ttf",
			gd_font => 'giant',
			ptsize  => 18,
			bgcolor => "#FFFF00",
		},
		CREATE_OPTIONS => [    #'ttf',
			'rect'
		],
		SECRET => "pft,fnsqgfjkm",
		PARTICLE_OPTIONS => [100],
	);
}


=head3
Get from Redis storage id user, then by this id 
find user hash and get password in md5 form, then eq this passwords 
=cut

sub password_check() {

	#my $self = shift;
	my @credentials = @_;
	my $redis       = Redis->new();    #( server => '127.0.0.1:6379');
	my $user_name_hash = md5_hex($credentials[0]);
	my $user_id = $redis->get("id:$user_name_hash");
	if ($user_id) {
		my $user_pas_hash = $redis->get("user:$user_id:pass");
		
		my $md5_cred_pass = md5_hex( $credentials[1] );

		if ( $user_pas_hash eq $md5_cred_pass ) {
			$redis->quit();
			return $credentials[0];
		}
	}	
	$redis->quit();
	return;
}

sub login_mode() {
	my $self      = shift;
	my $frame     = $self->load_tmpl("index.tmpl.html");	
	# заполняем параметрами
	$frame->param(		
		AUTH_PAGE => 1,
		AUTH_FORM => 1
	);
	return $frame->output;
}

sub register_init() {
	my $self     = shift;
	my $frame     = $self->load_tmpl("index.tmpl.html");
	# заполняем параметрами
	$frame->param(
		AUTH_PAGE => 1,
		REG_PAGE => 1
	);
	return $frame->output;
}

sub register() {
	my $self                        = shift;
	my $user_name                   = "";
	my $password                    = "";
	my $password_confirm            = "";
	my $email                       = "";
	my $passwords_coincides_err     = 1;
	my $password_novalid_err        = 1;
	my $username_already_exists_err = 1;
	my $username_novalid_err        = 1;
	my $capcha_coincides_err        = 1;
	my $email_novalid_err           = 1;

	my $all_valid = 1;    #flag that shows that all as ok and we can proceed

	$user_name        = $self->query->param("user_name");
	$password         = $self->query->param("password");
	$password_confirm = $self->query->param("password_confirm");
	$email            = $self->query->param("user_email");

	my $redis        = Redis->new();          #Add new redis connection
	my $security_obj = SecurityProc->new();
	my $user_name_md5 = md5_hex($user_name);
	
	#check for valid values of parameters;
	if ($user_name) {

		#username checking (existance... end maybe something else)
		$username_novalid_err = 0;
		my $user_name_id = "id:$user_name_md5";
		if ( $redis->exists($user_name_id) ) {
			$username_already_exists_err = 1;
			$all_valid                   = 0;
		}
		else {
			$username_already_exists_err = 0;
		}

		#password checking
		if($password eq ""){
			$all_valid = 0;
			$password_novalid_err = 1;
		}else{
			$password_novalid_err = 0;
		}
		if ( $password eq $password_confirm ) {
			$passwords_coincides_err = 0;
		}
		else {
			$passwords_coincides_err = 1;
			$all_valid               = 0;
		}
		

		#capcha here
		$capcha_coincides_err = 0;
		my $request = $self->query;
		unless (
			$self->captcha_verify(
				$request->cookie("hash"),
				$self->query->param("reg_captcha")
			)
		  )
		{
			$capcha_coincides_err = 1;
			$all_valid            = 0;
		}

		#email block
		$email_novalid_err = 0;

	}
	else { $all_valid = 0; }

	#final step add user into database
	if ( $all_valid == 1 ) {
		my $md5hex_password = md5_hex($password);

		#if(!defined $self->dbh){
		#	print "DBH IS NOT DEFINED\n";
		#}

		my $status =
		  $self->add_user_into_database_redis( $redis, $user_name,
			$md5hex_password, $email );
		$all_valid = $status ? 1 : 0;
	}
	my $frame     = $self->load_tmpl("index.tmpl.html");	
	# заполняем параметрами
	if ( $all_valid == 1 ) {
		#add user if all right		
		$frame->param( REG_DONE => 1 );
		$frame->param( user_name => $user_name );
	}
	else {
		$frame->param(
			user_name        => $user_name,
			password         => $password,
			password_confirm => $password_confirm,
			user_email       => $email,

			#optional parameters for error handling
			passwords_coincides_err     => $passwords_coincides_err,
			password_novalid_err        => $password_novalid_err,
			username_already_exists_err => $username_already_exists_err,
			username_novalid_err        => $username_novalid_err,
			email_novalid_err           => $email_novalid_err,
			capcha_coincides_err        => $capcha_coincides_err
		);
	}
	$frame->param(
		AUTH_PAGE => 1,
		REG_PAGE => 1		
	);
	$redis->quit();
	return $frame->output;
}

sub add_user_into_database_redis() {
	my ( $self, $redis, $user_name, $user_password, $user_email ) = @_;
	my $user_name_md5 = md5_hex($user_name);
	my $new_user_id = $redis->incr("users:nextId");
	my $set_ok = $redis->set( "id:$user_name_md5", $new_user_id );
	$set_ok = $redis->set( "user:$new_user_id:login", $user_name );
	$set_ok = $redis->set( "user:$new_user_id:email", $user_email );
	$set_ok = $redis->set( "user:$new_user_id:pass",  $user_password );
	
	my $status = 0;
	if($set_ok){
		$status = 1;
	}
	
	return $status;
}

sub auth_test {
	my $self = shift;
	return $self->redirect('podmanager.cgi');
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
sub cgiapp_postrun {
	my $self = shift;
	$self->header_add( -Content_Type => 'text/html; charset=UTF-8' );
}

#The page that will be returned if user will passwrong parameter;
sub autoload_mode() {
	return 'This page does not exist. Sorry :(';
}

=head3  get_reg_captcha
Create CAPTCHA image for new registration 
=cut

sub get_reg_captcha() {

	my $self = shift;
	return $self->captcha_create;
}

=head3 logout
Cancel the current user session
=cut

sub logout() {
	my $self = shift;
	$self->authen->logout();	
	return $self->redirect('index.cgi');
}

1;
