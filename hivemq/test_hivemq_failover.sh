#!/bin/bash

# -----------------------------
# HiveMQ Cluster Failover Test
# -----------------------------

MQTT_HOST="nginx_lb"
MQTT_PORT=1883
TOPIC="text/bridge"
PUBLISH_INTERVAL=2   # seconds between messages

echo "=== Clearing retained messages ==="
docker exec -i mqtt_client mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT -t $TOPIC -n -r

echo "=== Starting subscriber in background ==="
docker exec -i mqtt_client sh -c "mosquitto_sub -h $MQTT_HOST -p $MQTT_PORT -t $TOPIC" &
SUB_PID=$!
sleep 2

echo "=== Publishing messages every $PUBLISH_INTERVAL seconds ==="
COUNT=1
while [ $COUNT -le 10 ]; do
    MESSAGE="Message $COUNT"
    docker exec -i mqtt_client mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT -t $TOPIC -m "$MESSAGE"
    echo "Published: $MESSAGE"

    # Simulate failover after 3 messages
    if [ $COUNT -eq 3 ]; then
        echo "=== Stopping HiveMQ broker hivemq1 to simulate failover ==="
        docker stop hivemq1
    fi

    sleep $PUBLISH_INTERVAL
    COUNT=$((COUNT + 1))
done

echo "=== Restarting broker for recovery ==="
docker start hivemq1

# Allow subscriber to receive remaining messages
sleep 5
kill $SUB_PID
echo "=== Failover test complete ==="
