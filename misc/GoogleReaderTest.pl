use WebService::Google::Reader;

$user = "pozdpl";
$pass = "208216";

my $reader = WebService::Google::Reader->new(
	username => $user,
	password => $pass,
);

if(!$reader->_login()){
	print "Reader is defined\n";
	print $reader->_login();
	exit;
}

my $feed = $reader->unread( count => 10 );
my @entries = $feed->entries;

# Fetch past entries.
#while ($reader->more($feed)) {
#    my @entries = $feed->entries;
#}

foreach $entry (@entries){
	#$entry->title('My Post');
    #$entry->content('The content of my post.');
	print $entry->title() . "\n";
	print $entry->content() . "\n";
	print $entry->link->href . "\n";
	#print $entry->as_xml;
	print $entry->summary() . "\n";
}