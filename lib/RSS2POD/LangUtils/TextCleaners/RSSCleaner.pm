#!/usr/bin/perl
package RSS2POD::LangUtils::TextCleaners::RSSCleaner;

require Exporter;
use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
@ISA = qw(Exporter);
$VERSION = '0.01';
@EXPORT = qw(RSSProc);
#@EXPORT_OK = qw( );


use warnings;
use Sys::Syslog qw(:standard);
use POSIX;

use XML::RSS;

sub RSSProc{
	my($RawRSSFeed) = @_;
	my $rss = new XML::RSS;
	$rss->parse($RawRSSFeed);
	my @list;

	foreach my $item (@{$rss->{'items'}}) {
     	push(@list,$item->{'description'});
     	#print "title: $item->{'title'}\n";
     	#print "link: $item->{'link'}\n\n";
     	#print "=========================================\n";
     	#print "$item->{'description'}\n\n";
 	}
 	foreach my $t (@list){
 		print $t;	
 	}
 	#print $rss->as_string;
}
1;
__END__