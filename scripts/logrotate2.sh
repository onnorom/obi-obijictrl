#!/bin/bash

# make a named pipe:
mkfifo /dev/mypipe
# redirect stdout and stderr to the named pipe:
&> /dev/mypipe
#read from mypipe into a file:
#cat < /dev/mypipe > /var/log/log.txt &

LOGFILE="/path/to/log/file"
SEMAPHORE="/path/to/log/file.semaphore"

while : ; do
  read line
  if [[ $line != "" ]]; then
    while [[ -f $SEMAPHORE ]]; do
    #/bin/sleep 1s
      /bin/sleep 0.5s
    done
    printf "%s\n" "$line" >> $LOGFILE
  fi
done < /dev/mypipe &

touch /path/to/log/file.semaphore
mv /path/to/log/file /path/to/archive/of/log/file
rm /path/to/log/file.semaphore
