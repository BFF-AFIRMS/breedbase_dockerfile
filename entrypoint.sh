#!/bin/bash

# Wait for the docker compose post_start to finish
echo "Waiting for post_start to finish"

while [ ! -f /tmp/post_start.finished ]; do
  echo "-------------------"
  cat /tmp/post_start.log | tee > /tmp/post_start.seen.log
  num_lines_seen=$(wc -l /tmp/post_start.seen.log)
  tail -n+$(expr 1 + $num_lines_seen) /tmp/post_start.log
  sleep 1
done

echo "entrypoint begins"
tail -f /dev/null