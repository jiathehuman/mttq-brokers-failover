# MQTT Bridge with Load Balancer and Failover

This project implements a robust MQTT broker setup with load balancing, health checking, and automatic failover using Docker Compose.

## 🏗️ Architecture

```
┌─────────────────┐     ┌─────────────────┐
│   MQTT Client   │────▶│  Load Balancer  │
│                 │     │   (nginx:8883)  │
└─────────────────┘     └─────────┬───────┘
                                  │
                    ┌─────────────┼─────────────┐
                    ▼             ▼             ▼
            ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
            │    Parent    │ │   Child 1    │ │   Child 2    │
            │   Broker     │ │   Broker     │ │   Broker     │
            │ (Primary)    │ │  (Backup)    │ │  (Backup)    │
            └──────┬───────┘ └──────┬───────┘ └──────┬───────┘
                   │                │                │
                   └────────────────┼────────────────┘
                                    │
                            ┌───────▼───────┐
                            │ Health Checker │
                            │  (MQTT Ping)   │
                            └───────────────┘
```

### Components

- **nginx Load Balancer**: Routes MQTT traffic with 45-second failover timeout
- **Parent Broker (Hub)**: Primary MQTT broker, central message hub
- **Child Brokers**: Backup brokers that sync with parent, act as clients
- **Health Checker**: Monitors broker health using MQTT ping every 10 seconds

## 🚀 Quick Start

### 1. Automated Setup (Recommended)
```bash
# Run comprehensive test and setup
./test-complete-setup.sh
```

This script will:
- Set up Docker network and volumes
- Start all brokers in correct order
- Start load balancer with health checking
- Run connectivity and failover tests
- Keep services running for use

### 2. Manual Setup

1. **Setup infrastructure**:
   ```bash
   ./setup.sh
   ```

2. **Start brokers**:
   ```bash
   # Start parent (hub) broker
   cd mosquitto-parent && docker-compose up -d && cd ..

   # Start child brokers (they connect to parent)
   cd mqtt-child1 && docker-compose up -d && cd ..
   cd mqtt-child2 && docker-compose up -d && cd ..

   # Start load balancer with health checker
   cd nginx-lb && docker-compose up -d && cd ..
   ```

3. **Verify setup**:
   ```bash
   # Check all services are running
   docker ps

   # Check health status
   curl http://localhost:8080/health
   ```

## 🔌 Usage

### Connect to Load Balancer
```bash
# Connect MQTT clients to load balancer
mosquitto_pub -h localhost -p 8883 -t "test/topic" -m "Hello World"
mosquitto_sub -h localhost -p 8883 -t "test/topic"
```

### Connect Directly to Brokers
```bash
# Parent broker (primary)
mosquitto_pub -h localhost -p 1883 -t "test/topic" -m "Direct to parent"

# Child brokers (backups)
mosquitto_pub -h localhost -p 1884 -t "test/topic" -m "Direct to child1"
mosquitto_pub -h localhost -p 1885 -t "test/topic" -m "Direct to child2"
```

### Monitor Health
```bash
# Get health status JSON
curl http://localhost:8080/health | jq

# Get simple status
curl http://localhost:8080/status

# Get nginx stats
curl http://localhost:8080/nginx_status
```

## 🔄 Failover Behavior

1. **Normal Operation**: All clients connect through load balancer to parent broker
2. **Parent Failure**: Load balancer automatically switches to child1 after 45 seconds
3. **Child1 Failure**: Load balancer switches to child2
4. **Recovery**: When parent comes back online, it becomes primary again

### Failover Timeline
- **Health Check Interval**: 10 seconds
- **Failure Detection**: 3 failed checks (30 seconds)
- **nginx Failover Timeout**: 45 seconds
- **Total Failover Time**: ~45-60 seconds

## 📁 Project Structure

```
test-mqtt/
├── README.md                          # This file
├── setup.sh                          # Infrastructure setup script
├── test-complete-setup.sh             # Comprehensive test script
├── mosquitto-parent/                  # Primary broker (hub)
│   ├── docker-compose.yml
│   └── config/mosquitto.conf
├── mqtt-child1/                       # Backup broker 1
│   ├── docker-compose.yml
│   └── config/mosquitto.config
├── mqtt-child2/                       # Backup broker 2
│   ├── docker-compose.yml
│   └── config/mosquitto.config
└── nginx-lb/                          # Load balancer & health checker
    ├── docker-compose.yml
    ├── Dockerfile
    ├── health-checker.py              # Python health monitoring
    └── config/nginx.conf              # Load balancer config
```

## ⚙️ Configuration Details

### Broker Configuration
- **Parent**: Pure hub, no bridge connections, central message store
- **Children**: Bridge to parent only, full bidirectional sync (`topic # in/out`)
- **No Message Loops**: Hub-spoke architecture prevents circular message routing

### Load Balancer Settings
- **Primary**: Parent broker (mosquitto-parent:1883)
- **Backups**: Child brokers marked as backup servers
- **Health Checks**: 3 failures in 45 seconds triggers failover
- **Connection Timeout**: 10 seconds for new connections

### Health Checker Configuration
```bash
CHECK_INTERVAL=10    # Health check every 10 seconds
TIMEOUT=5           # 5 second timeout per check
FAIL_THRESHOLD=3    # 3 consecutive failures = unhealthy
```

## 🐛 Troubleshooting

### Check Service Status
```bash
# View running containers
docker ps

# Check specific service logs
docker logs mosquitto-parent
docker logs mqtt-load-balancer
docker logs mqtt-health-checker
```

### Test Connectivity
```bash
# Test direct broker connections
docker run --rm --network mqtt-bridge-network eclipse-mosquitto:2.0 mosquitto_pub -h mosquitto-parent -p 1883 -t "test" -m "parent"
docker run --rm --network mqtt-bridge-network eclipse-mosquitto:2.0 mosquitto_pub -h mosquitto-child1 -p 1883 -t "test" -m "child1"

# Test load balancer connection
docker run --rm --network mqtt-bridge-network eclipse-mosquitto:2.0 mosquitto_pub -h mqtt-load-balancer -p 8883 -t "test" -m "lb"
```

### Check Network
```bash
# Verify network exists
docker network ls | grep mqtt-bridge-network

# Inspect network
docker network inspect mqtt-bridge-network
```

### Reset Everything
```bash
# Stop and remove all containers
cd nginx-lb && docker-compose down; cd ..
cd mqtt-child2 && docker-compose down; cd ..
cd mqtt-child1 && docker-compose down; cd ..
cd mosquitto-parent && docker-compose down; cd ..

# Remove network and volumes (optional)
docker network rm mqtt-bridge-network
docker volume rm mqtt-shared-data
```

## 🎯 Key Features

✅ **Automatic Failover**: 45-second failover to backup brokers
✅ **Health Monitoring**: Real-time MQTT ping health checks
✅ **Message Persistence**: Shared data volume across brokers
✅ **Loop Prevention**: Hub-spoke architecture eliminates message loops
✅ **Load Balancing**: nginx stream proxy with backup server support
✅ **Docker Integration**: Complete containerized setup
✅ **Monitoring API**: REST API for health status and metrics

## 📊 Monitoring

- **Health API**: `http://localhost:8080/health` - Detailed broker health status
- **Status Endpoint**: `http://localhost:8080/status` - Simple OK/ERROR status
- **nginx Stats**: `http://localhost:8080/nginx_status` - Load balancer statistics
- **Logs**: Docker logs available for all services

## 🔧 Customization

### Adjust Failover Timing
Edit `nginx-lb/config/nginx.conf`:
```nginx
server mosquitto-parent:1883 max_fails=3 fail_timeout=30s;  # 30 second failover
```

### Change Health Check Frequency
Edit `nginx-lb/docker-compose.yml`:
```yaml
environment:
  - CHECK_INTERVAL=5    # Check every 5 seconds
  - TIMEOUT=3          # 3 second timeout
```

### Add More Brokers
1. Copy `mqtt-child2` directory to `mqtt-child3`
2. Update port mapping in `docker-compose.yml`
3. Add to nginx upstream configuration
4. Update health checker broker list

This setup provides enterprise-grade MQTT broker redundancy with automatic failover, perfect for production IoT deployments!
    │                     │                     │
    └──── Bridges ────────┘                     │
          (One-way only)                        │
    └──────── Bridges ──────────────────────────┘
              (One-way only)
