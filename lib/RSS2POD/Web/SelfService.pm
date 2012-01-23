package SelfService;

use strict;
use warnings;
use Env;


use base 'CGI::Application';
use CGI::Application::Plugin::Session;
use CGI::Application::Plugin::Authentication;
use CGI::Application::Plugin::Redirect;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use RSS2POD::SecurityProc;
use Redis;
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
}

# Метод setup не  являеться  хуком  он  предназначен  для  конфигурирования
# конретного приложения и вызываеться вслед за хуком init в методе new
sub setup {
	my $self = shift;

	$self->run_modes(
		auth_display => \&PH_diplay_self_information,
		change => \&PH_change_user_info,
		login        => \&PH_login_mode,
		AUTOLOAD     => \&autoload_mode,
	);
	$self->start_mode("auth_display");
	if ( defined $ENV{APP_HOME} ) {
		$self->tmpl_path("$ENV{APP_HOME}/../html_templates/");
	}
	else {
		$self->tmpl_path("../html_templates/");
	}

	# добавляем режим для ошибок
	$self->error_mode( \&on_error );

	#here is the authentiacation  parameters
	$self->authen->config(
		STORE         => 'Session',
		LOGIN_RUNMODE => 'login',
	);
	$self->authen->protected_runmodes(qr/^auth_/);
}

=head3
Show selfservce page.
=cut

sub PH_diplay_self_information() {
	my $self  = shift;
	my $user_name  = $self->authen->username();
	my $frame = $self->load_tmpl("index.tmpl.html");

	# заполняем параметрами
	my $user_email = $self->get_user_email();
	$frame->param(
		SELFSERVICE_PAGE => 1,            #run selservice page
		user_email       => $user_email,
		user_name        => $user_name
	);
	return $frame->output;
}

sub PH_change_user_info() {
	my $self                    = shift;
	my $password                = "";
	my $password_confirm        = "";
	my $email                   = "";
	my $passwords_coincides_err = 1;
	my $password_novalid_err    = 1;
	my $email_novalid_err       = 1;

	my $all_valid = 1;    #flag that shows that all as ok and we can proceed

	$password         = $self->query->param("password");
	$password_confirm = $self->query->param("password_confirm");
	$email            = $self->query->param("user_email");

	my $user_name = $self->authen->username();

	my $redis        = Redis->new(); #Add new redis connection	

	#check for valid values of parameters;
	#password checking
	if ( $password eq $password_confirm ) {
		$passwords_coincides_err = 0;
	}
	else {
		$passwords_coincides_err = 1;
		$all_valid               = 0;
	}
	$password_novalid_err = 0;

	#email block
	my $secObj = new RSS2POD::SecurityProc();
	$email_novalid_err = 0;
	unless ($secObj->get_preg( $email, 'email' )){
		$email_novalid_err = 1;
		$all_valid = 0;
	}
	

	#final step add user into database
	if ( $all_valid == 1 ) {
		my $md5hex_password = md5_hex($password);
		my $status =
		  $self->update_user_info_in_database_redis( $redis, $user_name,
			$md5hex_password, $email );
		$all_valid = $status ? 1 : 0;
	}
	my $frame = $self->load_tmpl("index.tmpl.html");

	# заполняем параметрами
	if ( $all_valid == 1 ) {
		#add user if all right
		$frame->param( SELFSERVICE_PAGE => 1 );
		$frame->param(
			user_name  => $user_name,
			user_email => $email
		);
	}
	else {
		$frame->param(
			SELFSERVICE_PAGE => 1,
			user_name        => $user_name,
			password         => $password,
			password_confirm => $password_confirm,
			user_email       => $email,

			#optional parameters for error handling
			passwords_coincides_err => $passwords_coincides_err,
			password_novalid_err    => $password_novalid_err,
			email_novalid_err       => $email_novalid_err,
		);
	}	
	$redis->quit();
	return $frame->output;
}

sub update_user_info_in_database_redis() {
	my ( $self, $redis, $user_name, $user_password, $user_email ) = @_;
	my $user_name_md5 = md5_hex($user_name);
	my $user_id    = $redis->get("id:$user_name_md5");
	
	#my $set_ok = $redis->set( "id:$user_name_md5", $user_id );
	my $set_ok = $redis->set( "user:$user_id:email", $user_email );
	$set_ok = $redis->set( "user:$user_id:pass",  $user_password );

	my $status = 1;
	return $status;
}

sub get_user_email() {
	my $self       = shift;
	my $user_name  = $self->authen->username();
	my $redis      = Redis->new();
	my $user_name_md5 = md5_hex($user_name);
	my $user_id    = $redis->get("id:$user_name_md5");
	my $user_email = $redis->get("user:$user_id:email");
	$redis->quit();
	$user_email = "" unless defined $user_email;
	return $user_email;
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
sub cgiapp_postrun {
	my $self = shift;
	$self->header_add( -Content_Type => 'text/html; charset=UTF-8' );
}

#The page that will be returned if user will passwrong parameter;
sub autoload_mode() {
	return 'This page does not exist. Sorry :(';
}

1;
