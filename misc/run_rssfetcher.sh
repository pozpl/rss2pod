#!/bin/bash

#perl  ../bin/RssFetcherV2.pl 1>>/dev/null 2>>/dev/null & echo $!

perl  -I $1/lib -I $2 -I $3  ../bin/RssFetcherV2.pl --conf=$1/config/rss2pod.conf   1>>/dev/null 2>>/dev/null & echo $!
