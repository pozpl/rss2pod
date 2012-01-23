#!/usr/bin/perl
#use lib "../lib";



use strict;
use warnings;


#use base 'CGI::Application';
use RSS2POD::Web::SiteEngine;

SiteEngine->new->run;
