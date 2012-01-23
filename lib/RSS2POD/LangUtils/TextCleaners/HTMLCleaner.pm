#!/usr/bin/perl
package LangUtils::TextCleaners::HTMLCleaner;

require Exporter;
use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
@ISA = qw(Exporter);
$VERSION = '0.01';
@EXPORT = qw(HTMLProc TestHTML);
#@EXPORT_OK = qw( );


use warnings;
use Sys::Syslog qw(:standard);
use POSIX;
use HTML::TreeBuilder;
use HTML::Parser ();
use HTML::Tree;
#use HTML::DOM;
use HTML::FormatText;
use Lingua::Translit;

#use Text::TransMetaphone qw( trans_metaphone reverse_key );
#use Text::TransMetaphone::ru;
#use Text::TransMetaphone::en_US;

sub HTMLProc{
	my($RawHTMLContent) = @_;	
	my $tree = HTML::TreeBuilder->new_from_content($RawHTMLContent);	
	my $formatter = HTML::FormatText->new(leftmargin => 0, rightmargin => 50);	
	my $res = lc $formatter->format($tree);	
	$res =~ s/\[image\]//g;
	return $res;	
}

sub TestHTML{
	my($RawHTMLContent) = @_;
	
	my $tree = HTML::TreeBuilder->new_from_content($RawHTMLContent);
	
	my $formatter = HTML::FormatText->new(leftmargin => 0, rightmargin => 50);
	
	my $res = lc $formatter->format($tree);
	
	$res =~ s/\[image\]//g;
	
	$res =~ s/[^\w^ ^.^\n]//g;
	
	my $tr = new Lingua::Translit("ISO 9");
	
	$res =~ s/([a-z]+)/$tr->translit_reverse($1)/eg;
	
	$res;
	
}

sub Transcript{
	my $word = @_;
	my @keys = trans_metaphone ( $word );
	print "@keys";
	my $res = reverse_key ( $keys[0], "chr" );
	return $res;
}
1;
__END__