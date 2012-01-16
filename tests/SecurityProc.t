use Test::More tests => 11;
use Encode;
use lib "../lib";
use SecurityProc;

my $securityProc = new SecurityProc();
#digit cases
ok($securityProc->get_preg(123, 'digit'), "Number is treated as number");
ok($securityProc->get_preg('123', 'digit'), "String with number is treated as number");
ok(! $securityProc->get_preg("tes123", 'digit'), "String that contains digits is not digit");
ok(! $securityProc->get_preg("123dg", 'digit'), "String that starts with digits is not digit");

ok($securityProc->get_preg("validemail\@example.com", 'email'), "Valid email go smooth");
ok(! $securityProc->get_preg("no validemail\@example.com", 'email'), "No valid email fails");
ok(! $securityProc->get_preg("no/|validemail\@example.com", 'email'), "No valid email fails");
ok(! $securityProc->get_preg("no_validemailexample.com", 'email'), "No valid email fails");
ok($securityProc->get_preg("no+validemail\@example.com", 'email'), "Email with annotation (as google can use) is go forward");

ok(length($securityProc->trim_too_long_string("123456", 100)) == 6, "Trimer do not trim if not necessary");
ok(length($securityProc->trim_too_long_string("123456", 3)) == 3, "Trimer trimming works");   