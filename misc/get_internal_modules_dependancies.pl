#!/usr/bin/perl

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
			#print "$+{mod_name} \n";
			my $module_name = $+{mod_name};
			@modnames = ( @modnames, $module_name );
		}
	}
	return @modnames;
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


foreach my $mod_name ( keys %dep_mods_hash ) {
	if ( !exists $my_own_modules{$mod_name} ) {
		print "'$mod_name' => 0,\n";

	}
}		