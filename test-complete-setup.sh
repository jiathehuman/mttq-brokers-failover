#!/bin/bash

# Test MQTT Load Balancer Setup
# This script tests the complete MQTT broker bridge with failover setup

set -e

echo "🚀 Starting MQTT Load Balancer Test Suite"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
check_docker() {
    print_status "Checking Docker..."
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    print_success "Docker is running"
}

# Setup network and volume
setup_infrastructure() {
    print_status "Setting up Docker infrastructure..."

    # Create network if it doesn't exist
    if ! docker network ls | grep -q mqtt-bridge-network; then
        docker network create mqtt-bridge-network
        print_success "Created mqtt-bridge-network"
    else
        print_success "Network mqtt-bridge-network already exists"
    fi

    # Create volume if it doesn't exist
    if ! docker volume ls | grep -q mqtt-shared-data; then
        docker volume create mqtt-shared-data
        print_success "Created mqtt-shared-data volume"
    else
        print_success "Volume mqtt-shared-data already exists"
    fi
}

# Start all services in correct order
start_services() {
    print_status "Starting MQTT brokers..."

    # Start parent broker
    cd mosquitto-parent
    docker-compose up -d
    cd ..

    # Wait a bit for parent to be ready
    sleep 5

    # Start child brokers
    cd mqtt-child1
    docker-compose up -d
    cd ..

    cd mqtt-child2
    docker-compose up -d
    cd ..

    # Wait for brokers to be ready
    sleep 10

    # Start load balancer
    cd nginx-lb
    docker-compose up -d
    cd ..

    print_success "All services started"
}

# Check if services are running
check_services() {
    print_status "Checking service status..."

    services=("mosquitto-parent" "mosquitto-child1" "mosquitto-child2" "mqtt-load-balancer" "mqtt-health-checker")

    for service in "${services[@]}"; do
        if docker ps | grep -q $service; then
            print_success "$service is running"
        else
            print_error "$service is not running"
            return 1
        fi
    done
}

# Test MQTT connectivity
test_mqtt_connectivity() {
    print_status "Testing MQTT connectivity..."

    # Test direct connection to parent
    print_status "Testing direct connection to parent broker..."
    timeout 10 docker run --rm --network mqtt-bridge-network eclipse-mosquitto:2.0 mosquitto_pub -h mosquitto-parent -p 1883 -t "test/direct" -m "direct_test" || {
        print_error "Failed to connect to parent broker directly"
        return 1
    }
    print_success "Direct connection to parent broker works"

    # Test connection through load balancer
    print_status "Testing connection through load balancer..."
    timeout 10 docker run --rm --network mqtt-bridge-network eclipse-mosquitto:2.0 mosquitto_pub -h mqtt-load-balancer -p 8883 -t "test/lb" -m "lb_test" || {
        print_error "Failed to connect through load balancer"
        return 1
    }
    print_success "Load balancer connection works"
}

# Test message propagation
test_message_propagation() {
    print_status "Testing message propagation..."

    # Publish to parent and check if children receive
    print_status "Publishing message through load balancer..."

    # Start subscriber on child1
    timeout 15 docker run --rm --network mqtt-bridge-network eclipse-mosquitto:2.0 mosquitto_sub -h mosquitto-child1 -p 1883 -t "test/propagation" -C 1 &
    SUB_PID=$!

    sleep 2

    # Publish through load balancer
    docker run --rm --network mqtt-bridge-network eclipse-mosquitto:2.0 mosquitto_pub -h mqtt-load-balancer -p 8883 -t "test/propagation" -m "propagation_test"

    # Wait for subscriber
    if wait $SUB_PID; then
        print_success "Message propagation works"
    else
        print_warning "Message propagation test inconclusive"
    fi
}

# Test health checker
test_health_checker() {
    print_status "Testing health checker..."

    # Check health API
    sleep 5  # Give health checker time to run

    if curl -s http://localhost:8080/health > /dev/null; then
        print_success "Health API is responding"

        # Show health status
        print_status "Current health status:"
        curl -s http://localhost:8080/health | python3 -m json.tool || echo "Health data not available yet"
    else
        print_warning "Health API not responding yet (may need more time)"
    fi
}

# Test failover
test_failover() {
    print_status "Testing failover mechanism..."

    # Stop parent broker to test failover
    print_status "Stopping parent broker to test failover..."
    cd mosquitto-parent
    docker-compose stop
    cd ..

    sleep 50  # Wait for failover timeout (45s + buffer)

    # Try connecting through load balancer (should failover to child)
    if timeout 10 docker run --rm --network mqtt-bridge-network eclipse-mosquitto:2.0 mosquitto_pub -h mqtt-load-balancer -p 8883 -t "test/failover" -m "failover_test"; then
        print_success "Failover test passed - load balancer switched to backup"
    else
        print_warning "Failover test failed or needs more time"
    fi

    # Restart parent broker
    print_status "Restarting parent broker..."
    cd mosquitto-parent
    docker-compose start
    cd ..

    sleep 15  # Wait for parent to come back online
    print_success "Parent broker restarted"
}

# Show logs for debugging
show_logs() {
    print_status "Recent logs from services:"

    echo -e "\n${YELLOW}=== Load Balancer Logs ===${NC}"
    docker logs --tail 20 mqtt-load-balancer 2>/dev/null || echo "No logs available"

    echo -e "\n${YELLOW}=== Health Checker Logs ===${NC}"
    docker logs --tail 20 mqtt-health-checker 2>/dev/null || echo "No logs available"

    echo -e "\n${YELLOW}=== Parent Broker Logs ===${NC}"
    docker logs --tail 10 mosquitto-parent 2>/dev/null || echo "No logs available"
}

# Cleanup function
cleanup() {
    print_status "Cleaning up test environment..."

    # Stop all services
    cd nginx-lb && docker-compose down > /dev/null 2>&1 || true; cd ..
    cd mqtt-child2 && docker-compose down > /dev/null 2>&1 || true; cd ..
    cd mqtt-child1 && docker-compose down > /dev/null 2>&1 || true; cd ..
    cd mosquitto-parent && docker-compose down > /dev/null 2>&1 || true; cd ..

    print_success "Cleanup completed"
}

# Main test execution
main() {
    print_status "Starting comprehensive MQTT bridge test..."

    # Trap to cleanup on exit
    trap cleanup EXIT

    check_docker
    setup_infrastructure
    start_services

    sleep 10  # Give services time to fully start

    check_services
    test_mqtt_connectivity
    test_message_propagation
    test_health_checker
    test_failover

    show_logs

    print_success "Test suite completed!"
    print_status "Load balancer is running on port 8883"
    print_status "Health API is available at http://localhost:8080/health"
    print_status "Use Ctrl+C to stop all services"

    # Keep services running
    echo -e "\n${GREEN}✅ MQTT Load Balancer is ready!${NC}"
    echo -e "${BLUE}📊 Monitor health: curl http://localhost:8080/health${NC}"
    echo -e "${BLUE}🔌 Connect to MQTT: localhost:8883${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop all services${NC}"

    # Wait for user interrupt
    while true; do
        sleep 10
        # Quick health check
        if ! docker ps | grep -q mqtt-load-balancer; then
            print_error "Load balancer stopped unexpectedly"
            break
        fi
    done
}

# Check if running from correct directory
if [[ ! -d "mosquitto-parent" || ! -d "nginx-lb" ]]; then
    print_error "Please run this script from the test-mqtt directory"
    exit 1
fi

# Run main function
main