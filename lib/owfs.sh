#!/bin/bash

url=http://localhost:9393

#owfs='/mnt/owfs'
#pwd=`pwd`

#cd $owfs

for sensor in `ssh root@dockstar2 'cd /mnt/owfs && ls -1d 10.*'`
do
  temperature=`ssh root@dockstar2 cat /mnt/owfs/$sensor/temperature | sed 's/^ *//g'`
  curl -X POST -d "sensor=$sensor&value=$temperature" $url/temperature
done

while true
do
  for sensor in `ssh root@dockstar2 'cd /mnt/owfs && ls -1d 1D.*'`
  do
    pulses=`ssh root@dockstar2 cat /mnt/owfs/$sensor/counters.B`
    curl -X POST -d "sensor=$sensor&value=$pulses" $url/pulses
  done
  sleep 15
done
#cd $pwd
