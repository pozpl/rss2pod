#/usr/bin/perl
use CGI::Application::PSGI;
#use CGI::Application::Dispatch::PSGI;
use RSS2POD::Web::SiteEngine;
use RSS2POD::Web::Rss2PodCTL;
use RSS2POD::Web::AuthHandler;
use Plack::Builder;


my $app1 = sub {
    my $env = shift;
    my $app = SiteEngine->new({ QUERY => CGI::PSGI->new($env) });
    CGI::Application::PSGI->run($app);
};

my $app2 = sub {
    my $env = shift;
    my $app2 = Rss2PodCTL->new({ QUERY => CGI::PSGI->new($env) });
    CGI::Application::PSGI->run($app2);
};

my $app3 = sub {
    my $env = shift;
    my $app3 = AuthHandler->new({ QUERY => CGI::PSGI->new($env) });
    CGI::Application::PSGI->run($app3);
};



builder {
		enable "Plack::Middleware::Static",
          path => qr{^/(images|js|css|jslib|templates)/}, root => './';
		

        mount "/index.cgi" => builder {$app1};
        mount "/run_auth.cgi" => builder {$app3;};
        mount "/podmanager.cgi" => builder {$app2;};
};

#CGI::Application::Dispatch::PSGI->as_psgi(
#    prefix      => 'RSS2POD::Web',
#    
#    table       => [
#        '/index.cgi'                         => { app => 'SiteEngine'},
#        '/podmanager.cgi'          => { app => 'Rss2PodCTL' },        
#        '/run_auth.cgi'          => { app => 'AuthHandler' },        
#    ]
#  );