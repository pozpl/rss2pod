#!/usr/bin/perl


use strict;
use warnings;
use Sys::Syslog qw(:standard);
use Config::Simple;
use PodGenerateDaemon;
openlog( "pod_generator", "pid,perror,nofatal", "local0" );

my $server = PodGenerateDaemon->new(
		{
			'pidfile'    => 'none',
			'localport'  => 9996,
			'configfile' => "../config/pod_generator.conf"
		},
		\@ARGV
	);
$server->Bind();