#!/bin/bash

url=http://proto:4004

owfs='/mnt/owfs'
pwd=`pwd`

cd $owfs

for sensor in `ls -1d 10.*`
do
  temperature=`cat $sensor/temperature | sed 's/^ *//g'`
  curl -X POST -d "sensor=$sensor&value=$temperature" $url/temperature
done

for sensor in `ls -1d 1D.*`
do
  pulses=`cat uncached/$sensor/counters.B | sed 's/^ *//g'`
  curl -X POST -d "sensor=$sensor&value=$pulses" $url/pulses
done

cd $pwd
