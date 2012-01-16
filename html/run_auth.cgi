#!/usr/bin/perl
use strict;
use warnings;

use Web::AuthHandler;

use Module::Load;
load 'CGI::Application::Plugin::Authentication::Driver::Generic';

AuthHandler->new->run;


