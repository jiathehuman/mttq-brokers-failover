#!/bin/bash

MQTT_HOST="nginx_lb"
MQTT_PORT=1883
TOPIC="text/bridge"
PUBLISH_INTERVAL=2

echo "=== Clearing retained messages ==="
docker exec -i mqtt_client mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT -t $TOPIC -n -r

echo "=== Starting subscriber in detached mode ==="
docker exec -d mqtt_client sh -c "mosquitto_sub -h $MQTT_HOST -p $MQTT_PORT -t $TOPIC > /tmp/sub_output.log"

sleep 2

echo "=== Publishing messages every $PUBLISH_INTERVAL seconds ==="
COUNT=1
while [ $COUNT -le 10 ]; do
    MESSAGE="Message $COUNT"
    docker exec -i mqtt_client mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT -t $TOPIC -m "$MESSAGE"
    echo "Published: $MESSAGE"

    if [ $COUNT -eq 3 ]; then
        echo "=== Stopping broker1 to simulate failover ==="
        docker stop broker1
    fi

    sleep $PUBLISH_INTERVAL
    COUNT=$((COUNT + 1))
done

echo "=== Restarting broker1 ==="
docker start broker1

# Give subscriber time to receive messages
sleep 5
echo "=== Subscriber output ==="
docker exec -i mqtt_client cat /tmp/sub_output.log

# Clean up subscriber log
docker exec -i mqtt_client rm /tmp/sub_output.log

echo "=== Failover test complete ==="
