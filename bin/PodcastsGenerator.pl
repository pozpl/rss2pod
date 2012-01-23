#!/usr/bin/perl

use strict;
use warnings;
use Sys::Syslog qw(:standard);
use Config::Simple;
use Getopt::Long;
use RSS2POD::PodGenerateDaemon;

my $conf_file_path;
GetOptions(
	"conf=s" => \$conf_file_path,
);

$conf_file_path = defined $conf_file_path ? $conf_file_path : "../config/pod_generator.conf";

openlog( "pod_generator", "pid,perror,nofatal", "local0" );

my $server = PodGenerateDaemon->new(
	{
		'pidfile'    => 'none',
		'localport'  => 9996,
		'configfile' => $conf_file_path,
	},
	\@ARGV
);
$server->Bind();
