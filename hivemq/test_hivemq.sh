#!/bin/bash
MQTT_HOST="nginx_lb"
MQTT_PORT=1883

TOPIC1="text/bridge"
TOPIC2="alerts/bridge"

echo "=== Clearing retained messages ==="
docker exec -i mqtt_client mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT -t $TOPIC1 -n -r
docker exec -i mqtt_client mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT -t $TOPIC2 -n -r

echo "=== Starting subscriber in background ==="
# Run subscriber in background without TTY (-t removed)
docker exec -i mqtt_client sh -c "mosquitto_sub -h $MQTT_HOST -p $MQTT_PORT -t $TOPIC1 -t $TOPIC2" &

SUB_PID=$!
sleep 2

echo "=== Publishing test messages ==="
docker exec -i mqtt_client mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT -t $TOPIC1 -m "Hello HiveMQ"
docker exec -i mqtt_client mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT -t $TOPIC2 -m "Alert triggered"

echo "=== Messages sent! Subscriber should see them above ==="

sleep 5
kill $SUB_PID
echo "=== Test complete ==="
