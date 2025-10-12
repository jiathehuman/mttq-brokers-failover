#!/bin/sh
# Test HAProxy round robin with EMQX cluster
# Usage: ./test_round_robin.sh [COUNT]

COUNT=${1:-10}
TOPIC="test/rr"
CLIENT="emqx-mqtt-client"
HAPROXY="haproxy"

for i in $(seq 1 $COUNT); do
  MSG="Test round robin $i"
  echo "Publishing: $MSG"
  docker exec -it $CLIENT mosquitto_pub -h $HAPROXY -p 1883 -t $TOPIC -m "$MSG"
  sleep 1
  # Optional: print which EMQX node received it (if subscribers are running)
done

echo "Done. Check your EMQX node subscribers for message distribution."
