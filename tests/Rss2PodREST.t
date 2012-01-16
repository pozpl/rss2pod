use Test::WWW::Mechanize;
use Test::More tests => 12;
use Encode;
use lib "../lib";

use Redis;
use Digest::MD5 qw(md5 md5_hex md5_base64);

=head3
This function add fake user to enter into system.
Fake user will be added into redis environment.
=cut

sub add_test_user($$$) {
	my ( $user_name, $user_password, $user_email ) = @_;
	my $redis        = Redis->new();      #Add new redis connection
	my $user_name_md5 = md5_hex($user_name);
	my $user_name_id = "id:$user_name_md5";
	if ( !$redis->exists($user_name_id) ) {

		my $status =
		  add_user_into_database_redis( $redis, $user_name,
			md5_hex($user_password), $user_email );
		if ($status) {
			print "Crate fake user\n";
		}
		else {
			print "Cant create face user\n";
		}
	}
	$redis->quit();
}

=head3
Delete test user
=cut

sub delete_test_user($) {
	my ($user_name)  = @_;
	my $redis        = Redis->new();
	my $user_name_md5 = md5_hex($user_name);
	my $user_name_id = "id:$user_name_md5";
	if ( $redis->exists($user_name_id) ) {
		my $user_id = $redis->get($user_name_id);
		$redis->del("user:user_id:login");
		$redis->del("id:$user_name_md5");
		$redis->del("user:$user_id:email");
		my $del_ok = $redis->del("user:$user_id:pass");
		if ($del_ok) {
			print "Delete fake user\n";
		}
		else {
			print "Can't delete fake user\n";
		}
	}
	$redis->quit();
}

sub add_user_into_database_redis() {
	my ( $redis, $user_name, $user_password, $user_email ) = @_;
	my $new_user_id = $redis->incr("users:nextId");
	my $user_name_md5 = md5_hex($user_name);
	my $set_ok = $redis->set( "id:$user_name_md5", $new_user_id );
	$set_ok = $redis->set( "user:$new_user_id:login", $user_name );
	$set_ok = $redis->set( "user:$new_user_id:email", $user_email );
	$set_ok = $redis->set( "user:$new_user_id:pass",  $user_password );

	my $status = 0;
	if ($set_ok) {
		$status = 1;
	}

	return $status;
}

#my $mech = Test::WWW::Mechanize::CGIApp->new;
#$mech->app("Web::SelfService");

my $fake_user_name     = "test";
my $fake_user_password = "test_test";
my $fake_user_email    = "test\@fu.bar";
#call delete user before procedure is starting in case if previouse test go wrong
delete_test_user($fake_user_name);
add_test_user( $fake_user_name, $fake_user_password, $fake_user_email );

my $mech      = Test::WWW::Mechanize->new;
my %post_hash = (
	authen_username    => $fake_user_name,
	authen_password    => $fake_user_password,
	authen_loginbutton => "%D0%92%D0%BE%D0%B9%D1%82%D0%B8",
	destination        => ".%2Frun_auth.cgi",
	rm                 => "start"
);
$mech->post_ok( "http://localhost/FestRSS/run_auth.cgi",
	\%post_hash, "Load authentication" );
$mech->get_ok( "http://localhost/FestRSS/podmanager.cgi", "Load pod manager" );



delete_test_user($fake_user_name);