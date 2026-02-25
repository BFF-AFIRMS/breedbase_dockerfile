#!/bin/bash

# https://serverfault.com/a/103569
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/tmp/post_start.log 2>&1

# Everything below will go to the file 'log.out':

echo "running post_start"
sleep 3
echo "finished post_start"
touch /tmp/post_start.finished
