#!/usr/bin/perl

use lib "../lib";
use strict;
use warnings;
use Sys::Syslog qw(:standard);
use XML::RSS;


my $rss = XML::RSS->new( version => '2.0' );
=co
$rss->channel(
    title=>"My title", 
    link=>"http://localhost/rss.xml", 
    description=>"It is description",
    language=>"eng-ru", 
    rating=>"no", 
    copyright=>"free",
    pubDate=>"Thu, 23 Aug 1999 07:00:00 GMT",
    lastBuildDate=>"Thu, 23 Aug 1999 16:20:26 GMT", 
    docs=>'http://www.blahblah.org/fm.cdf',
    managingEditor=>"pozpl\@dvo.ru",
    webMaster=>"pozpl\@dvo.ru"
);
=cut
$rss->parsefile("my_rss.xml");
	
$rss->add_item(title => "GTKeyboard 0.85",
               # creates a guid field with permaLink=true
               permaLink  => "http://freshmeat.net/news/1999/06/21/930003829.html",
               # alternately creates a guid field with permaLink=false
               # guid     => "gtkeyboard-0.85"
               link => "http://localhost/lam",
               enclosure   => { url=>"http://localhost", type=>"application/x-bittorrent" },
               description => 'blah blah'
       );
$rss->save("my_rss.xml");