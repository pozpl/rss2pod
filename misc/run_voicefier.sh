#!/bin/bash

#perl  ../bin/VoicefyDiemon.pl 1>>/dev/null 2>>/dev/null & echo $!

perl  -I $1/lib -I $2 -I $3  ../bin/VoicefyDiemon.pl --conf=$1/config/rss2pod.conf  1>>/dev/null 2>>/dev/null & echo $!