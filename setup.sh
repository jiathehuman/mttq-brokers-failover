#!/bin/bash

# MQTT Broker Bridge Setup Script
echo "Setting up MQTT Broker Bridge with Failover..."

# Create log directories
mkdir -p mosquitto-parent/log
mkdir -p mqtt-child1/log
mkdir -p mqtt-child2/log

# Set proper permissions
chmod -R 755 mosquitto-parent/log mqtt-child1/log mqtt-child2/log
chmod 644 mosquitto-parent/config/mosquitto.conf
chmod 644 mqtt-child1/config/mosquitto.config
chmod 644 mqtt-child2/config/mosquitto.config

# Create shared Docker network
echo "Creating shared Docker network..."
docker network create mqtt-bridge-network 2>/dev/null || echo "Network already exists"

# Create shared volume for data persistence
echo "Creating shared Docker volume..."
docker volume create mqtt-shared-data 2>/dev/null || echo "Volume already exists"

echo "Setup complete!"
echo ""
echo "To start the brokers:"
echo "1. cd mosquitto-parent && docker-compose up -d"
echo "2. cd mqtt-child1 && docker-compose up -d"
echo "3. cd mqtt-child2 && docker-compose up -d"
echo ""
echo "Parent broker will be available on port 1883"
echo "Child1 broker will be available on port 1884"
echo "Child2 broker will be available on port 1885"
echo ""
echo "Architecture:"
echo "- Parent broker: Main entry point for clients"
echo "- Child brokers: Bridge to each other for redundancy"
echo "- All brokers share persistent data storage"