#!/bin/bash

perl -I $1/lib -I $2 -I $3 ../local/bin/starman index.psgi  1>>/dev/null 2>>/dev/null & echo $!

#perl -I ../local/lib/perl5/ -I ../local/lib/perl5/x86_64-linux-debug-thread-multi/ -I ../lib/ ../local/bin/starman index.psgi 
