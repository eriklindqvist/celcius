#!/bin/bash

url=http://proto:4004/temperature

owfs='/mnt/owfs'
pwd=`pwd`

cd $owfs

for sensor in `ls -1d 10.*`
do
  temperature=`cat $sensor/temperature | sed 's/^ *//g'`
  curl -X POST -d "sensor=$sensor&value=$temperature" $url
done

cd $pwd
