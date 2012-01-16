#!/usr/bin/perl
package LangUtils::TextCleaners::TEXTCleaner;

require Exporter;
use strict;
use utf8;
#use encoding 'utf8';
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
@ISA = qw(Exporter);
$VERSION = '0.01';
@EXPORT = qw(TEXTProc);
#@EXPORT_OK = qw( );


use warnings;
use Sys::Syslog qw(:standard);
use POSIX;
use Lingua::Translit;

sub TEXTProc{
	
	my($RAWText,$LANG) = @_;
	
	#try to replace url
	$RAWText =~ s/(http|ftp|https):\/\/[\w\-_]+(\.[\w\-_]+)+([\w\-\.,@?^=%&amp;:\/~\+#]*[\w\-\@?^=%&amp;\/~\+#])?/ReplaceURL($LANG)/eg;
	
	#try to replace email
	$RAWText =~s/\w+([-+.']\w+)*@\w+([-.]\w+)*\.\w+([-.]\w+)*/ReplaceEMAIL($LANG)/eg;
	
	if($LANG eq "ru"){
		$RAWText =~ s/([a-z]+)/replace_t( $1 )/eg;		
	}
	
	$RAWText =~ s/[^\w^ ^.^\n]//g;
	$RAWText =~ s/[\n_\^]/ /g;
	$RAWText =~ s/\.//g;
	
	return $RAWText;	
}

sub replace_t($){
	my $word = shift;
	my $tr = new Lingua::Translit("ISO 9");	
	my $translit_word = $tr->translit_reverse($word);
	$translit_word =~ s/w/"в"/eg;
	$translit_word =~ s/q/"ку"/eg;
	return $translit_word;
}

sub ReplaceURL{
	my($LANG) = shift;
	my $res = "";
	if($LANG eq "en"){
		$res = "url";
	}
	if($LANG eq "ru"){
		$res = "ссылка";
	}
	return $res;
}

sub ReplaceEMAIL{
	my($LANG) = shift;
	my $res = "";
	if($LANG eq "en"){
		$res = "email";
	}
	if($LANG eq "ru"){
		$res = "емэил";
	}
	return $res;
}

sub ReplaceJAPAN{
	my($LANG) = shift;
	my $res = "";
	if($LANG eq "en"){
		$res = " japan string";
	}
	if($LANG eq "ru"){
		$res = " японские иероглифы";
	}
	return $res;
}
1;
__END__
