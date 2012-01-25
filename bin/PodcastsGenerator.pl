#!/usr/bin/perl

use strict;
use warnings;
use Sys::Syslog qw(:standard);
use Config::Simple;
use Getopt::Long;
use RSS2POD::PodGenerateDaemon;

my $daemon_conf_file_path;
my $rss_to_pod_conf;
GetOptions(
	"daemon_conf=s"   => \$daemon_conf_file_path,
	"rss2pod_conf=s"  => \$rss_to_pod_conf,
);

$daemon_conf_file_path =   defined $daemon_conf_file_path   ? $daemon_conf_file_path
  :                                                          "../config/pod_generator.conf";
$rss_to_pod_conf =  defined $rss_to_pod_conf ? $rss_to_pod_conf 
					:                          "../config/rss2pod.conf";

openlog( "pod_generator", "pid,perror,nofatal", "local0" );

my $server = RSS2POD::PodGenerateDaemon->new(
	{
		'pidfile'      => 'none',
		'localport'    => 9996,
		'configfile'   => $daemon_conf_file_path,
		'rss2pod_conf' => $rss_to_pod_conf,
	},
	\@ARGV
);
$server->Bind();
