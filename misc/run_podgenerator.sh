#!/bin/bash

#perl  ../bin/PodcastsGenerator.pl 1>>/dev/null 2>>/dev/null & echo $!

perl -I $1/lib -I $2 -I $3 ../bin/PodcastsGenerator.pl --daemon_conf=$1/config/pod_generator.conf --rss2pod_conf=$1/config/rss2pod.conf  1>>/dev/null 2>>/dev/null & echo $!