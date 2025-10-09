docker exec -it mqtt_client mosquitto_pub -h nginx_lb -p 1883 -t sensors/temp -m "23.4°C" -q 1
docker exec -it mqtt_client mosquitto_sub -h nginx_lb -p 1883 -t sensors/# -q 1


docker exec -it mqtt_client mosquitto_sub -h nginx_lb -p 1883 -t sensors/#

docker exec -it mqtt_client mosquitto_pub -h nginx_lb -p 1883 -t sensors/temp -m "23.4°C"


clear retained docker exec -it mqtt_client mosquitto_pub -h nginx_lb -p 1883 -t sensors/temp -r -n
Nginx achieves connection failover: Clients can reconnect to another broker if one fails


By default, mosquitto_pub does not set the retained flag, but some broker configurations (or HiveMQ defaults) may retain the last message for a topic.

if you subscribe
docker exec -it mqtt_client mosquitto_sub -h nginx_lb -p 1883 -t sensors/#

The broker sends the retained message immediately upon subscription.

The "infinite" messages are not truly infinite — they are the broker sending the last retained message repeatedly to new subscriptions.