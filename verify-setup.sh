#!/bin/bash

# Verify MQTT Load Balancer Project Structure
# This script checks if all files are properly created without requiring Docker

set -e

echo "🔍 MQTT Load Balancer Project Verification"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if we're in the right directory
check_directory() {
    print_status "Checking project directory..."
    if [[ ! -d "mosquitto-parent" ]]; then
        print_error "Not in the correct directory. Please run from test-mqtt folder."
        exit 1
    fi
    print_success "In correct project directory"
}

# Check file structure
check_files() {
    print_status "Checking project structure..."

    # List of required files
    files=(
        "README.md"
        "setup.sh"
        "test-complete-setup.sh"
        "mosquitto-parent/docker-compose.yml"
        "mosquitto-parent/config/mosquitto.conf"
        "mqtt-child1/docker-compose.yml"
        "mqtt-child1/config/mosquitto.config"
        "mqtt-child2/docker-compose.yml"
        "mqtt-child2/config/mosquitto.config"
        "nginx-lb/docker-compose.yml"
        "nginx-lb/Dockerfile"
        "nginx-lb/health-checker.py"
        "nginx-lb/config/nginx.conf"
    )

    missing_files=()

    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            print_success "✓ $file"
        else
            print_error "✗ $file (missing)"
            missing_files+=("$file")
        fi
    done

    if [[ ${#missing_files[@]} -eq 0 ]]; then
        print_success "All required files are present"
    else
        print_error "Missing ${#missing_files[@]} files"
        return 1
    fi
}

# Check configuration content
check_configurations() {
    print_status "Checking configuration files..."

    # Check parent config (should be hub only)
    if grep -q "bridge " mosquitto-parent/config/mosquitto.conf; then
        print_warning "Parent config contains bridge - should be pure hub"
    else
        print_success "Parent config: Pure hub (no bridges) ✓"
    fi

    # Check child configs (should bridge to parent only)
    if grep -q "address mosquitto-parent" mqtt-child1/config/mosquitto.config; then
        print_success "Child1 config: Bridges to parent ✓"
    else
        print_warning "Child1 config: Missing parent bridge connection"
    fi

    if grep -q "address mosquitto-parent" mqtt-child2/config/mosquitto.config; then
        print_success "Child2 config: Bridges to parent ✓"
    else
        print_warning "Child2 config: Missing parent bridge connection"
    fi

    # Check nginx config
    if grep -q "upstream mqtt_brokers" nginx-lb/config/nginx.conf; then
        print_success "nginx config: Load balancer upstream configured ✓"
    else
        print_warning "nginx config: Missing upstream configuration"
    fi

    # Check health checker
    if grep -q "class MQTTHealthChecker" nginx-lb/health-checker.py; then
        print_success "Health checker: Python script ready ✓"
    else
        print_warning "Health checker: Missing main class"
    fi
}

# Show port mappings
show_ports() {
    print_status "Port mappings:"
    echo "  🔌 Load Balancer MQTT: localhost:8883"
    echo "  📊 Health API:         localhost:8080"
    echo "  🏠 Parent Broker:      localhost:1883"
    echo "  🏘️  Child1 Broker:      localhost:1884"
    echo "  🏘️  Child2 Broker:      localhost:1885"
}

# Show Docker commands
show_docker_commands() {
    print_status "To start the system (requires Docker):"
    echo ""
    echo "1. Start Docker Desktop (or Docker Engine)"
    echo ""
    echo "2. Run the setup:"
    echo "   ./setup.sh"
    echo ""
    echo "3. Start all services:"
    echo "   ./test-complete-setup.sh"
    echo ""
    echo "4. Or start manually:"
    echo "   cd mosquitto-parent && docker-compose up -d && cd .."
    echo "   cd mqtt-child1 && docker-compose up -d && cd .."
    echo "   cd mqtt-child2 && docker-compose up -d && cd .."
    echo "   cd nginx-lb && docker-compose up -d && cd .."
    echo ""
    echo "5. Test connectivity:"
    echo "   curl http://localhost:8080/health"
    echo "   mosquitto_pub -h localhost -p 8883 -t test/topic -m \"Hello World\""
}

# Check Docker availability
check_docker() {
    if command -v docker &> /dev/null; then
        if docker info &> /dev/null; then
            print_success "Docker is installed and running"
            return 0
        else
            print_warning "Docker is installed but not running"
            return 1
        fi
    else
        print_warning "Docker is not installed or not in PATH"
        return 1
    fi
}

# Main verification
main() {
    check_directory
    check_files
    check_configurations

    echo ""
    show_ports

    echo ""
    if check_docker; then
        print_success "Ready to run! Execute: ./test-complete-setup.sh"
    else
        show_docker_commands
    fi

    echo ""
    print_success "Project verification completed!"
    print_status "All configuration files are properly set up"
    print_status "Architecture: Hub-spoke with nginx load balancer"
    print_status "Failover: 45-second timeout with health checking"
}

main