#!/bin/bash
# Automated EMQX failover test script
# 1. Start subscribers via HAProxy
# 2. Publish test messages
# 3. Simulate node failure
# 4. Publish more messages
# 5. Restart node and verify recovery

set -e

CLIENT_CONTAINER=emqx-mqtt-client
HAPROXY_HOST=haproxy
TOPIC="test/rr"

# Clean up old logs
rm -f subscriber_failover.log publisher_failover.log

echo "[1/5] Starting subscriber via HAProxy..."
docker exec -d $CLIENT_CONTAINER mosquitto_sub -h $HAPROXY_HOST -p 1883 -t $TOPIC -v > subscriber_failover.log 2>&1 &
SUB_PID=$!
sleep 2

echo "[2/5] Publishing initial messages via HAProxy..."
for i in {1..3}; do
  docker exec $CLIENT_CONTAINER mosquitto_pub -h $HAPROXY_HOST -p 1883 -t $TOPIC -m "Initial message $i" | tee -a publisher_failover.log
  sleep 1
done
sleep 2

echo "[3/5] Simulating node failure: stopping emqx1..."
docker stop emqx1
sleep 3

echo "[4/5] Publishing messages after node failure..."
for i in {4..6}; do
  docker exec $CLIENT_CONTAINER mosquitto_pub -h $HAPROXY_HOST -p 1883 -t $TOPIC -m "After failover $i" | tee -a publisher_failover.log
  sleep 1
done
sleep 2

echo "[5/5] Restarting emqx1 to verify recovery..."
docker start emqx1
sleep 5

echo "Publishing messages after recovery..."
for i in {7..9}; do
  docker exec $CLIENT_CONTAINER mosquitto_pub -h $HAPROXY_HOST -p 1883 -t $TOPIC -m "After recovery $i" | tee -a publisher_failover.log
  sleep 1
done
sleep 2

kill $SUB_PID || true

echo "\n--- Subscriber log ---"
cat subscriber_failover.log

echo "\n--- Publisher log ---"
cat publisher_failover.log

echo "\n[Done] Check logs above for message delivery during failover and recovery."
