package SiteEngine;


use strict;
use warnings;

use base 'CGI::Application';
#use base 'CGI::Application::FastCGI';
#use CGI::Application::Plugin::Apache;
#use CGI::Application::Plugin::Apache2::Request;
use CGI::Application::Plugin::Session;
use CGI::Application::Plugin::Authentication;
use CGI::Application::Plugin::Redirect;

#preventing of use old brousers
use CGI::Application::Plugin::BrowserDetect;

use JSON;
use Redis;
use Sys::Syslog qw(:standard);
use CGI::Application::Plugin::Config::Simple;

#cgiapp_init run right before setup method
#I will put here some Session parameters
sub cgiapp_init() {
	my $self = shift;
	#Init configuration
	$self->config_file('../config/webapp.conf');

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
	openlog( "Rss2PodSiteEngine", "pid,perror,nofatal", "local0" );
}

# Метод setup не  являеться  хуком  он  предназначен  для  конфигурирования
# конретного приложения и вызываеться вслед за хуком init в методе new
sub setup {
	my $self = shift;

	$self->run_modes( AUTOLOAD => \&autoload_mode,
					  start => \&PH_index_page
					);
	#$self->start_mode("index_page");
	
	if(defined $ENV{APP_HOME}){
		$self->tmpl_path("$ENV{APP_HOME}/../html_templates/");
	}else{
		$self->tmpl_path("../html_templates/");
	}
	#$self->tmpl_path("$ENV{APP_HOME}/../html_templates/");

	# добавляем режим для ошибок
	#if($self->config->debug){
	#	$self->error_mode( \&on_error );
	#}
}

#sub cgiapp_prerun {
#	my $self = shift;
#
#	# Redirect to login, if necessary
#	unless ( $self->authen->is_authenticated ) {
#		$self->prerun_mode('login');
#	}
#}

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
sub autoload_mode() {
	return 'This page does not exist. Sorry :(';
}



sub PH_index_page(){
	my $self     = shift;
	#first of all detect brouser and redirect to some page if it is too old
	$self->detect_brouser();
	
	my $frame_template = $self->load_tmpl("index.tmpl.html");
	#my $main_content_tmpl = $self->load_tmpl("index_main_content.tmpl.html");
	#my $sidebar_content_tmpl = $self->load_tmpl("index_sidebar_content.tmpl.html");
	#my $load_js_tmpl = $self->load_tmpl("script_load_index.tmpl.html");
	
	$frame_template->param(
			INDEX_PAGE => 1
			#MAIN_CONTENT =>  $main_content_tmpl->output(),
			#SIDEBAR_CONTENT => $sidebar_content_tmpl->output(),
			#LOAD_JS => $load_js_tmpl->output()			
		);
	
	$self->header_add( -Content_Type => 'text/html; charset=UTF-8' );
	return $frame_template->output();	
}

=head3
Get brouser version, and if this version is too old then redirect it into some page
for downloading new one.
Now this page is browsers.yandex.ru 
=cut
sub detect_brouser(){
	my $self     = shift;
	 my $browser = $self->browser;
	#check IE
     if ($browser->ie && $browser->major() < 8){     	
     	$self->redirect("http://browsers.yandex.ru/");
     }	
}

1;
