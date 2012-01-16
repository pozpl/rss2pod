package SecurityProc;

use strict;
use warnings;

use Moose;

#sub new {
#	my $pkg  = shift;
#	my $self = {@_};
#	return bless $self, $pkg;
#}


############################################
# Usage      : SecurityProcObj->get_preg("user@mail.com", 'email');
# Purpose    : check input variables for compiliance with some rules
# Returns    : true or false
# Parameters : input string, rule type
# Throws     : no exceptions
# Comments   : Check if input string argument is coverred by
#			   rule. E.g. if the email is a valid email, the digit is a digit, etc/
# See Also   : n/a
sub get_preg() {
	my ( $self, $argument, $regexp ) = @_;
	my $pregexpr = "";
	my %type_regexp_map = (
		'digit' => qr/\A\d{1,}\Z/,
		'email' => qr|^([0-9a-zA-Z+\\/\\._-])+[@]([0-9a-zA-Z-])+([.]([0-9a-zA-Z-])+)*$|,		
	);
	my $is_true = 0;
	$pregexpr = $type_regexp_map{$regexp};
	if ( $argument =~ /$pregexpr/ ) {
		$is_true = 1;
	}
	return $is_true;
}

############################################
# Usage      : SecurityProcObj->trim_too_long_string("yesnosomebod yd sdfsf", 10);
# Purpose    : Trim string if this string is too long
# Returns    : trimmed string
# Parameters : string - string to trim, max_str_length - max string lenght 
# Throws     : no exceptions
# Comments   : ???
# See Also   : n/a
sub trim_too_long_string(){
	my ($self,$string, $max_str_length) = @_;
	my $return_str = $string;
	if(length($string) > $max_str_length){
		$return_str = substr($string, 0, $max_str_length);
	}
	return $return_str;
}

1;
