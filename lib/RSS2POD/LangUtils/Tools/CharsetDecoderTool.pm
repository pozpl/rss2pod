#!/usr/bin/perl
package LangUtils::Tools::CharsetDecoderTool;

require Exporter;
use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
@ISA = qw(Exporter);
$VERSION = '0.01';
@EXPORT = qw(DecodeString);
#@EXPORT_OK = qw( );


use warnings;
use Sys::Syslog qw(:standard);
use POSIX;
use Encode qw(from_to);


sub DecodeString{
	my($Charset,$String) = @_;
	from_to($String, $Charset, "utf-8");
	return $String;
}
1;
__END__