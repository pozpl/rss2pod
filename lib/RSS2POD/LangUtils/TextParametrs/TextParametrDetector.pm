#!/usr/bin/perl
package LangUtils::TextParametrs::TextParametrDetector;

require Exporter;
use strict;
use utf8;
use encoding 'utf8';

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
@ISA = qw(Exporter);
$VERSION = '0.01';
@EXPORT = qw(DetectMainParametrs);
#@EXPORT_OK = qw(DetectMainParametrs );


use warnings;
use Sys::Syslog qw(:standard);
use POSIX;

use Encode::Detect::Detector;
#use Lingua::DetectCyrillic;
use Lingua::Identify qw(:language_identification :language_manipulation);
use Encode qw(from_to);


sub DetectMainParametrs{
		my($text) = shift;
		my $text_charset = "";
		
		$text_charset = detect($text);
		deactivate_all_languages();
		activate_language('en');
		activate_language('ru');
		my $language = langof($text);
		print "LANG: $language \n";
		print "TEXT: $text\n";
		$language =~ tr/A-Z/a-z/;
		
		return ($text_charset,$language);
}

=deprecated
sub DetectMainParametrs{
		my($text) = shift;
		my $TextCharset = "";
		
		$TextCharset = detect($text);
		
		my(@words);
        @words = split(/ /,$text);        
        my $CyrDetector = Lingua::DetectCyrillic->new( MaxTokens => 400, DetectAllLang => 0 );
        my ( $Coding, $Language, $CharsProcessed, $Algorithm ) = $CyrDetector->Detect(@words);		
				
		
		if ( $Language eq "NoLang" ) {
                $Language = "en";
        }		
		
		if( !defined($TextCharset) || $TextCharset eq ""){
			$TextCharset = "UTF-8";
		}
		
		if( $TextCharset eq "UTF-8"){			
			if( $text =~ m/[а-я]+/){					
				$Language = "ru";
			}else{
				$Language = "en"
			}
		}
		return ($TextCharset,$Language);
}
=cut
1;
__END__