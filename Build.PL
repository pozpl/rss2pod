#!/usr/bin/perl
use App::Build;

my $build = App::Build->new(
	dist_name     => 'RSS2POD',
	dist_version  => '0.1',
	dist_author   => 'pozdpl@gmail.com',
	dist_abstract => 'The RSS2POD installation piece',
	extra_dirs =>
	  [ 'html', 'html_templates', 'config', 'misc', 'tests', 'bin', 'lib', ],
	license        => 'perl',
	build_requires => {
		'App::Build'    => 0,       # needed for installing the software
		'Module::Build' => 0.38,    #
	},
	requires => {
		'perl'                                     => '5.14.2',
		'Audio::ConvTools'                         => 0,
		'Config::Simple'                           => 0,
		'IO::Socket::INET'                         => 0,
		'HTML::TreeBuilder'                        => 0,
		'Encode'                                   => 0,
		'Net::Daemon'                              => 0,
		'Getopt::Long'                             => 2.38,
		'CGI::Application'                         => 0,
		'CGI::Application::Plugin::Session'        => 0,
		'CGI::Application::Plugin::Config::Simple' => 1.01,
		'CGI::Application::Plugin::Redirect'       => 0,
		'CGI::Application::Plugin::BrowserDetect'  => 0,
		'CGI::Application::Plugin::Authentication' => 0,
		'CGI::Application::Plugin::CAPTCHA'        => 0,
		'CGI::Application::Plugin::Stream'         => 0,
		'CGI::Application::PSGI'                   => 0,
		'CGI::Session::Driver::redis'              => 0,
		'GD'                                       => 2.46,
		'HTML::Tree'                               => 0,
		'warnings'                                 => 0,
		'Moose::Role'                              => 0,
		'AnyEvent'                                 => 0,
		'XML::Feed'                                => 0,
		'Env'                                      => 0,
		'HTML::FormatText'                         => 0,
		'HTML::Template'                           => 0,
		'AnyEvent::Feed'                           => 0,
		'strict'                                   => 0,
		'diagnostics'                              => 0,
		'IO::Socket'                               => 0,
		'IPC::Run3'                                => 0,
		'HTML::Parser'                             => 0,
		'AppConfig'                                => 0,
		'bytes'                                    => 0,
		'Sys::Syslog'                              => 0,
		'Feed::Find'                               => 0,
		'POSIX'                                    => 0,
		'Plack'                                    => 0,
		'Lingua::Translit'                         => 0,
		'Lingua::Identify'                         => 0.5,
		'LWP::Simple'                              => 0,
		'Plack::Middleware::Static'                => 0,
		'Moose'                                    => 0,
		'Redis'                                    => 0,
		'Starman'                                  => 0,
		'MP3::Tag'                                 => 0,
		'Time::HiRes'                              => 0,
		'threads'                                  => 1.80,
		'utf8'                                     => 0,
		'MIME::Base64'                             => 0,
		'Encode::Detect::Detector'                 => 0,
		'JSON'                                     => 0,
		'Template::Tiny'                           => 0,
		'XML::RSS'                                 => 0,
	},
	install_base => '/opt/rss2pod',
);

$build->create_build_script;
