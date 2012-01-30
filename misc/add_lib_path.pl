#!/usr/bin/perl
BEGIN {
	use File::Spec;
	my $this_file_path = File::Spec->rel2abs(__FILE__)
	  ;    # Путь до исполняемого файла

	my $path_to_project = '.';
	if ( $this_file_path =~ qr{(?<project_path>.*?)\/misc\/add_lib_path.pl}xms )
	{
		$path_to_project = $+{project_path};
	}
	$project_lib = $path_to_project . '/lib';
	$local_lib   = $path_to_project . '/local/lib/perl5';
	
	
	my @perl_minus_v = `perl -v`;
	
	$perl_arch = 'x86_64-linux';
	if($perl_minus_v[1] =~ qr{(?:.*?)built \s+ for \s+ (?<perl_arch>.*?)$}xms){
		$perl_arch = $+{perl_arch};
	}
	$local_arch_lib =	$path_to_project . '/local/lib/perl5/' . $perl_arch;
}

use lib $project_lib;
use lib $local_lib;
use lib $local_arch_lib;

#use lib '/home/pozpl/workspace/rss2pod/lib';
#use lib '/home/pozpl/workspace/rss2pod/local/lib/perl5';
#use lib '/home/pozpl/workspace/rss2pod/local/lib/perl5/x86_64-linux-thread-debug-multi';

1;
