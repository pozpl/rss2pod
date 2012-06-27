#!/usr/bin/perl
use Cwd ( 'abs_path', 'getcwd' );

my $current_working_dir = getcwd();


#First of all check if carton is installed
if ( ! is_carton_installed() ) {	
	if(! is_local_cpanm_installed()){
		install_cpanm();
	}
	install_carton();
}
install_app_build_module($current_working_dir);
install_deps($current_working_dir);


############################################
# Usage      : is_carton_installed()
# Purpose    : check if carton executable is in the local dir
# Returns    : true or false
# Parameters : none
# Throws     : no exceptions
# Comments   : Now this function check only in local folder non system wide
# See Also   : n/a
sub is_carton_installed() {
	my $path_to_carton_exe = './local/bin/carton';

	my $is_installed = ( -e $path_to_carton_exe ) ? 1 : 0;

	return $is_installed;
}

############################################
# Usage      : is_local_cpanm_installed()
# Purpose    : check if executable for cpanm is in the project dir
# Returns    : true or false
# Parameters : none
# Throws     : no exceptions
# Comments   : No system wide checking, only in project directory
# See Also   : n/a
sub is_local_cpanm_installed(){
	my $path_to_cpanm_exe = './cpanm';

	my $is_installed = ( -e $path_to_cpanm_exe ) ? 1 : 0;

	return $is_installed;
}


############################################
# Usage      : install_cpanm()
# Purpose    : install cpanm selfcontained distribution
# Returns    : none
# Parameters : none
# Throws     : no exceptions
# Comments   : This procedure jast run shell command, and print it's out to STDOUT
# See Also   : n/a
sub install_cpanm() {	
	open( my $sh_out, "curl -LO http://xrl.us/cpanm && chmod +x cpanm |" ) || die "Failed: $!\n";
	while ( my $out_line = <$sh_out> ) {
		print $ps_line;
	}
}

############################################
# Usage      : install_carton()
# Purpose    : install carton into local subfolder via cpanm
# Returns    : none
# Parameters : none
# Throws     : no exceptions
# Comments   : This procedure jast run shell command, and print it's out to STDOUT
# See Also   : n/a
sub install_carton() {
    #PATH=$PATH:/path/to/your/project/local/bin
	#perl -I ./local/lib/perl5/ ./local/bin/carton install
	open( my $sh_out, "cpanm Carton -l local |" ) || die "Failed: $!\n";
	while ( my $out_line = <$sh_out> ) {
		print $ps_line;
	}
}

############################################
# Usage      : install_app_build_module()
# Purpose    : install App::Builder module
# Returns    : none
# Parameters : cwd - project dir path  
# Throws     : no exceptions
# Comments   : Now I use App::Builder for my Build.PL staff. Maybe in future
#			   I will migrate ot Module::Build but not now.
# See Also   : n/a
sub install_app_build_module(){
	my ($cwd) = @_;
	
	my $local_bin_path = $cwd . '/local/bin';
	open( my $sh_out, "PATH=$PATH:$local_bin_path |" ) || die "Failed: $!\n";
	while ( my $out_line = <$sh_out> ) {
		print $ps_line;
	}
	
	$local_lib   = $cwd . '/local/lib/perl5';	
	
	my @perl_minus_v = `perl -v`;	
	$perl_arch = 'x86_64-linux';
	if($perl_minus_v[1] =~ qr{(?:.*?)built \s+ for \s+ (?<perl_arch>.*?)$}xms){
		$perl_arch = $+{perl_arch};
	}
	$local_arch_lib =	$path_to_project . '/local/lib/perl5/' . $perl_arch;
	
	
	open( my $sh_out, "perl -I $local_lib -I $local_arch_lib ./local/bin/carton App::Build |" ) || die "Failed: $!\n";
	while ( my $out_line = <$sh_out> ) {
		print $ps_line;
	}
}


############################################
# Usage      : install_deps()
# Purpose    : install dependancies via carton
# Returns    : none
# Parameters : cwd - project dir path  
# Throws     : no exceptions
# Comments   : This procedure jast run shell command, and print it's out to STDOUT
# See Also   : n/a
sub install_deps(){
	my ($cwd) = @_;
	
	my $local_bin_path = $cwd . '/local/bin';
	open( my $sh_out, "PATH=$PATH:$local_bin_path |" ) || die "Failed: $!\n";
	while ( my $out_line = <$sh_out> ) {
		print $ps_line;
	}
	
	$local_lib   = $cwd . '/local/lib/perl5';	
	
	my @perl_minus_v = `perl -v`;	
	$perl_arch = 'x86_64-linux';
	if($perl_minus_v[1] =~ qr{(?:.*?)built \s+ for \s+ (?<perl_arch>.*?)$}xms){
		$perl_arch = $+{perl_arch};
	}
	$local_arch_lib =	$path_to_project . '/local/lib/perl5/' . $perl_arch;
	
	
	open( my $sh_out, "perl -I $local_lib -I $local_arch_lib ./local/bin/carton install --force |" ) || die "Failed: $!\n";
	while ( my $out_line = <$sh_out> ) {
		print $ps_line;
	}
}

1;
