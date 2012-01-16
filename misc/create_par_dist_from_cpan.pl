#!/usr/bin/perl

#Create new repoditory if not exists
BEGIN {
	use PAR::Repository;
	use PAR::Repository::DBM;
	my $PAR_DIST_DIR = "./par_dist/";
	my $repo = PAR::Repository->new( path => $PAR_DIST_DIR );
}

my $PAR_DIST_DIR = "./par_dist/";
use PAR::Repository;
use PAR::Repository::DBM;
use PAR { repository => 'file://./par_dist/'
};    #"./par_dist/*";#{ file => $PAR_DIST_DIR . "*", fallback=>1 };

use PAR::Dist::FromCPAN;
use Config;
use PPI;
use HTML::Perlinfo::Modules;
use Cwd ( 'abs_path', 'getcwd' );

sub get_name_by_key($) {
	my $str = shift;
	$str =~ s!/!::!g;
	$str =~ s!.pm$!!i;
	$str =~ s!^auto::(.+)::.*!$1!;
	return $str;
}

sub get_mod_names_from_file($) {
	my ($file_path) = @_;
	chop $file_path;

	print ">>$file_path| \n";
	my $Document = PPI::Document->new( $file_path, readonly => 1 );

	#print "Document: $Document";
	my $modules = $Document->find(
		sub {
			$_[1]->isa('PPI::Statement::Include')
			  && ( $_[1]->type eq 'use' || $_[1]->type eq 'require' );
		}
	);
	my @mod_names = ();
	my $mod_reg_ex =
qr/use(\s{1,}|\s{1,}base\s{1,}(\'?|qw\/))(?<mod_name>[a-zA-Z:0-9]+?)(\'?|\/|\s{1,}([a-zA-Z0-9_:\(\)]+?));/;
	foreach my $mod_string ( @{$modules} ) {
		if ( $mod_string =~ $mod_reg_ex ) {

			print "$+{mod_name} \n";
			my $module_name = $+{mod_name};
			@modnames = ( @modnames, $module_name );
		}
	}
	return @modnames;
}

{
	my $repo = PAR::Repository->new( path => $PAR_DIST_DIR );
	print "BEGIN MODE";
	opendir( DIR, $PAR_DIST_DIR );
	@FILES_IN_PAR_DIST = readdir(DIR);
	print "@FILES_IN_PAR_DIST\n";
	foreach my $par_dist_fl (@FILES_IN_PAR_DIST) {

		#my $par_reg = qr/^*?\.par/;
		if ( $par_dist_fl =~ m/\.par/ ) {
			print "$par_dist_fl ";
			if ( index( $par_dist_fl, "-''-", 0 ) > 0 ) {
				my $inject_success = $repo->inject(
					file        => $PAR_DIST_DIR . $par_dist_fl,
					distversion => "1.0",
					arch        => "any_arch",
					perlversion => "any_version"
				);
				print "Inject success " if $inject_success;
			}
			else {
				my $inject_success =
				  $repo->inject( file => $PAR_DIST_DIR . $par_dist_fl );
				print "Inject success " if $inject_success;
			}
			print "added \n";
		}
		print "\n";
	}
}

my $current_working_dir = getcwd();

my @find_results_pl = `find ../bin/* | grep "\.pl\$"`;
my @find_results_pm = `find ../lib/* | grep "\.pm\$"`;
@find_results_pm = ( @find_results_pm, @find_results_pl );

my %my_own_modules = {};
foreach $pm (@find_results_pm) {
	if ( $pm =~ /\.\.\/lib\/(?<mod_path>.+?\.pm)/ ) {

		#print "$+{mod_path}\n";
		$my_own_modules{ get_name_by_key( $+{mod_path} ) } = $+{mod_path};
	}
}

push @find_results_pl, @find_results_pm;

#
chomp(@find_results_pl);

my $installed_modules_hash_ref =
  ( HTML::Perlinfo::Modules::find_modules( "", \@INC ) )[1];

my %installed_mod_hash = %{$installed_modules_hash_ref};

#print %installed_mod_hash;
#print @find_results_pm;
my %dep_mods_hash;
foreach my $proj_file (@find_results_pm) {
	my @dep_modules = get_mod_names_from_file( abs_path($proj_file) );
	@dep_mods_hash{@dep_modules} = ();
}

my $repo = PAR::Repository->new( path => abs_path($PAR_DIST_DIR) );

open( my $mod_req_file, "<", "MOD_REQ" );
while ( my $single_req = <$mod_req_file> ) {
	chop $single_req;
	unless($single_req eq ""){
		$dep_mods_hash{$single_req} = "1";
	}
}

foreach my $mod_name ( keys %dep_mods_hash ) {
	if ( !exists $my_own_modules{$mod_name} ) {
		print "Mod name: $mod_name \n";

		chdir($current_working_dir);
		my $repo_ans = $repo->query_module( name => $mod_name );

		my $repo_ans_count = @{repo_ans};
		print "in repo is $repo_ans_count\n";

		my $is_module_for_this_perl = 0;

		foreach my $ans ( @{$repo_ans} ) {

			if ( $ans =~ m/any_version/ ) {
				$is_module_for_this_perl = 1;
				print "This module is any version \n";
			}
			else {
				my $perl_arch = $Config{archname};

				my $perl_version = $^V;
				$perl_version =~ s/v//;

				if ( $ans =~ m/$perl_arch\-$perl_version/ ) {
					$is_module_for_this_perl = 1;
					print "Modeule for this version of perl\n";
				}
			}
		}

		if (
			(
				!exists $installed_mod_hash{$mod_name}
				|| $dep_mods_hash{$mod_name} eq "1"
			)
			&& !$is_module_for_this_perl
		  )
		{
			print "installing .... $mod_name \n";
			cpan_to_par(
				pattern               => $mod_name,
				out                   => abs_path($PAR_DIST_DIR),
				verbose               => 1,
				follow                => 1,
				test                  => 1,
				auto_detect_pure_perl => 1
			);
		}
	}
}

