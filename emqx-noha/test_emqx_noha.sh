#!/bin/sh
# Test script for EMQX NOHA setup
# Usage: ./test_emqx_noha.sh

set -e

# Publish a message from mosquitto-client to emqx4 (parent)
echo "Publishing to emqx4-noha from mosquitto-client..."
docker compose exec mosquitto-client-noha mosquitto_pub -h emqx4-noha -t test/topic -m "hello from mosquitto-client"

# Subscribe from mosquitto-client to verify message from parent
echo "Subscribing on mosquitto-client (should receive messages from emqx4-noha)..."
docker compose exec -T mosquitto-client-noha mosquitto_sub -h emqx4-noha -t test/topic -C 1 &
SUB_PID=$!
sleep 1

docker compose exec mosquitto-client-noha mosquitto_pub -h emqx4-noha -t test/topic -m "test message to parent"
wait $SUB_PID

echo "Testing bridge: publish from emqx-child1 to parent (should be received by mosquitto-client)"
docker compose exec emqx-child1-noha sh -c 'emqx_ctl clients pub -t test/topic -m "from child1"'

sleep 2
echo "Done. Check logs for bridge status:"
docker compose logs emqx-child1-noha emqx-child2-noha emqx4-noha
