#!/bin/bash

url=http://localhost:9393

while true
do
  for sensor in `ssh dockstar2 'cd /mnt/owfs && ls -1d 10.*'`
  do
    temperature=`ssh dockstar2 cat /mnt/owfs/uncached/$sensor/temperature | sed 's/^ *//g'`
    curl -X POST -d "sensor=$sensor&value=$temperature" $url/temperature
  done

  i=0
  while [ $i -lt 4 ]
  do
    for sensor in `ssh dockstar2 'cd /mnt/owfs && ls -1d 1D.*'`
    do
      pulses=`ssh dockstar2 cat /mnt/owfs/uncached/$sensor/counters.B`
      curl -X POST -d "sensor=$sensor&value=$pulses" $url/pulses
    done
    i=$(( $i + 1 ))
    sleep 60
  done
done
