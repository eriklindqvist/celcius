#!/bin/bash

uteuid=87
inneuid=82
nyauid=187

tdtool=$(/usr/bin/tdtool -l)

utetemp=`echo "$tdtool" | grep fineoffset | awk '{if ($3 == '$uteuid') print $4;}' | sed 's/°//g'`
innetemp=`echo "$tdtool" | grep fineoffset | awk '{if ($3 == '$inneuid') print $4;}' | sed 's/°//g'`
nyatemp=`echo "$tdtool" | grep fineoffset | awk '{if ($3 == '$nyauid') print $4;}' | sed 's/°//g'`

curl -X POST -d "sensor='$uteuid'&value='$utetemp'" http://10.0.0.80:9393/temperature
