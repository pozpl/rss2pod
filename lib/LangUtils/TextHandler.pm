package LangUtils::TextHandler;


use warnings;
use Sys::Syslog qw(:standard);
use POSIX;
use JSON;
use Encode;

use LangUtils::TextParametrs::TextParametrDetector qw(DetectMainParametrs);
use LangUtils::Tools::CharsetDecoderTool qw(DecodeString);
use LangUtils::TextCleaners::HTMLCleaner qw(HTMLProc);
use LangUtils::TextCleaners::TEXTCleaner qw(TEXTProc);

require Exporter;
use strict;
use utf8;
use encoding 'utf8';

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
@ISA = qw(Exporter);
$VERSION = '0.01';
@EXPORT = qw(prepare_text);



sub prepare_text($){
	my($text) = @_;
	my ($TextCharset,$Language) = DetectMainParametrs($text);
	$text = HTMLProc($text);	
	$text = TEXTProc($text,$Language);
	my($result)={text=> Encode::encode( 'utf8',$text ),
		         lang=>$Language, 
		  
	}; 
	#my $json_text = JSON->new->allow_nonref->encode($result); #encode_json $result;
	#return $json_text;
	$result;
}
1;
__END__