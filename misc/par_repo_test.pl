#!/usr/bin/perl
#use lib "./par_dist/";

my $PAR_DIST_DIR = "./par_dist/";

my $PAR_DIST_DIR = "./par_dist/";
use PAR::Repository;
use PAR { repository => 'file://./par_dist/'};    #"./par_dist/*";#{ file => $PAR_DIST_DIR . "*", fallback=>1 };

use PAR::Dist::FromCPAN;
use Config;
use PPI;
use HTML::Perlinfo::Modules;
use Cwd ( 'abs_path', 'getcwd' );
use Config;


my $current_working_dir = getcwd();

my $repo = PAR::Repository->new( path => abs_path($PAR_DIST_DIR) );

=lolly
open(my $mod_req_file, "<", "MOD_REQ");
while(my $single_req = <$mod_req_file>){
	chop $single_req;
	$dep_mods_hash{$single_req} = "";
}


foreach my $mod_name ( keys %dep_mods_hash ) {
	
		print "Mod name: $mod_name| \n";

		chdir($current_working_dir);
		my $repo_ans = $repo->query_module(name => $mod_name);
		my $repo_ans_count = @{$repo_ans};
		if ( !exists $installed_mod_hash{$mod_name} && $repo_ans_count == 0 ) {
			print "installing .... $mod_name \n";
			cpan_to_par(
				pattern => $mod_name,
				out     => abs_path($PAR_DIST_DIR),
				verbose => 1,
				follow  => 1,
				test    => 1,
				auto_detect_pure_perl => 1
				);			
		}
	
}

=cut

=loly
use PAR::Repository;
use PAR::Repository::DBM;
my $repo = PAR::Repository->new( path => $PAR_DIST_DIR );
print "BEGIN MODE";
opendir( DIR, $PAR_DIST_DIR );
@FILES_IN_PAR_DIST = readdir(DIR);
print "@FILES_IN_PAR_DIST\n";
foreach my $par_dist_fl (@FILES_IN_PAR_DIST) {

	my $par_reg = qr/^*?\.par/;
	if ( $par_dist_fl =~ $par_reg ) {
		print "$par_dist_fl ";
		print "added ";
		my $file_without_version_reg = qr/^*?--*?/;
		if ( index( $par_dist_fl, "--", 0 ) > 0 ) {
			my $inject_success = $repo->inject(
				file        => $PAR_DIST_DIR . $par_dist_fl,
				distversion => "1.0",
				arch => "any_arch",
				perlversion => "any_version"
			);
			print "Inject success\n" if $inject_success;
		}
		else {
			my $inject_success =
			  $repo->inject( file => $PAR_DIST_DIR . $par_dist_fl );
			print "Inject success\n" if $inject_success;
		}
	}
	print "\n";
}
=cut
=salormun
BEGIN {
	my $PAR_DIST_DIR = "./par_dist/";

	use PAR::Repository;
	use PAR::Repository::DBM;
	my $repo = PAR::Repository->new( path => $PAR_DIST_DIR );
	print "BEGIN MODE";
	opendir( DIR, $PAR_DIST_DIR );
	@FILES_IN_PAR_DIST = readdir(DIR);
	print "@FILES_IN_PAR_DIST\n";
	foreach my $par_dist_fl (@FILES_IN_PAR_DIST) {
		print "$par_dist_fl ";
		my $par_reg = qr/^*?\.par/;
		if($par_dist_fl =~ $par_reg){
			print "added ";
			my $inject_success = $repo->inject( file => $PAR_DIST_DIR . $par_dist_fl );
			print "Inject success\n" if $inject_success;
		}
		print "\n";
	}
}

my $PAR_DIST_DIR = "./par_dist/";
use PAR::Repository;
use PAR { repository => 'file://./par_dist/'};    #"./par_dist/*";#{ file => $PAR_DIST_DIR . "*", fallback=>1 };

use PAR::Dist::FromCPAN;
use Config;
use PPI;
use HTML::Perlinfo::Modules;
use Cwd ( 'abs_path', 'getcwd' );
=cut

my $repo = PAR::Repository->new( path => $PAR_DIST_DIR );

my $module_name = "HTML::Parser";

my $repo_ans = $repo->query_module(name => $module_name);
print "repo ans is defined\n" if defined $repo_ans;
my @repoans_arr = @{$repo_ans};
print "Repo answer for -> $module_name @repoans_arr\n";
my $ans_count = @repoans_arr;
print "Count of els in answer is $ans_count\n";

my $mod_name_reg = qr/(any_version|thread)/;

print "$Config{archname}\n";

foreach my $ans (@{$repo_ans}){
	print ">$ans\n";
	if($ans =~ m/$mod_name_reg/){
		print "Modname reg fired\n";
		my $VERSION =  $^V; 
		$VERSION  =~ s/v//;
		print $VERSION . "\n";
		if($ans =~ m/$VERSION/){
			
		}
	}
}
