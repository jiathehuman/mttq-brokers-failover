#!/bin/sh
# Launches a subscriber for each EMQX node in the background
# Usage: ./test_subscribers.sh

CLIENT="emqx-mqtt-client"
TOPIC="test/rr"
PORT=1883

for NODE in emqx1 emqx2 emqx3 emqx4 emqx5; do
  echo "Starting subscriber for $NODE..."
  docker exec -d $CLIENT mosquitto_sub -h $NODE -p $PORT -t $TOPIC -v > subscriber_$NODE.log 2>&1 &
done

echo "All subscribers started. Check subscriber_emqxX.log files for output."
