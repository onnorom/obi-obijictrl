#!/usr/bin/env bash
MAXLOG=2
for i in `seq $((MAXLOG-1)) -1 1`; do 
  #mv "log."{$i,$((i+1))}; 
  echo "log."{$i,$((i+1))}; 
done 

#mv log log.1

#trap { exec &>"$LOGFILE"; } HUP
