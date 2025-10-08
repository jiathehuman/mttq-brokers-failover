# Test MTTQ
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

## Creating volumes and shared data

`/usr/local/bin/docker network create mqtt-bridge-network`

`/usr/local/bin/docker volume create mqtt-shared-data`

## Check Logs

`/usr/local/bin/docker logs mosquitto-parent`

## Test

```
# Test publishing to parent broker
/usr/local/bin/docker exec -it mosquitto-parent mosquitto_pub -h localhost -t test/topic -m "Hello from parent"

# Test subscribing from child1
/usr/local/bin/docker exec -it mosquitto-child1 mosquitto_sub -h localhost -t test/topic

# Test subscribing from child2
/usr/local/bin/docker exec -it mosquitto-child2 mosquitto_sub -h localhost -t test/topic
```

Parent - bridge all topics to and from children, no loops
child 1 and 2 (redunduncy) - bridges all topics between each other, bridge all topics to/from parent and operates if parent fails

Message Flow
Normal Operation:

Client → Parent → Distributed to Child1 & Child2
Child1 Local → Parent → Child2 receives copy
Child2 Local → Parent → Child1 receives copy
Parent Fails:

Child1 & Child2 continue operating independently
They have complete message history up to failure point
Clients switch connection to Child1 or Child2

