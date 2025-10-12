docker exec -u 0 -it emqx1 /bin/sh
docker exec -u 0 -it emqx2 /bin/sh
docker exec -u 0 -it emqx3 /bin/sh
docker exec -u 0 -it emqx4 /bin/sh
docker exec -u 0 -it emqx5 /bin/sh


mosquitto_sub -h localhost -p 1883 -t test/proxy -v -u admin -P public
docker exec -it emqx1 mosquitto_pub -h emqx-haproxy -p 1883 -t test/proxy -m "hello from emqx1" -u admin -P public


docker exec -u 0 -it emqx1 sh -c "apt-get update && apt-get install -y mosquitto-clients"

apt-get update && apt-get install -y mosquitto-clients
mosquitto_sub -h emqx-haproxy -p 1883 -t test/a -v

apt-get update && apt-get install -y iputils-ping
ping emqx2



docker exec -it emqx-mqtt-client mosquitto_pub -h emqx-haproxy -p 1883 -t test/proxy -m "hello from mqtt-client"

mosquitto_pub -h emqx-mqtt-client -p 1883 -t test/proxy -m "hello from mqtt-client"

mosquitto_pub -h emqx-haproxy -p 1883 -t test/proxy -m "hello from emqx1"

docker exec -it emqx-mqtt-client mosquitto_sub -h emqx-haproxy -p 1883 -t test/proxy -v

# Test Client subscribe, publish from haproxy
docker exec -it emqx-mqtt-client mosquitto_sub -h emqx1 -p 1883 -t test/topic -v
docker exec -it emqx-mqtt-client mosquitto_pub -h haproxy -p 1883 -t test/topic -m "Hello from client via HAProxy"

# Testing nginx active connections
(base) main@Jias-MacBook-Air-3 test-mqtt % docker exec -it emqx-nginx netstat -tnp
Active Internet connections (w/o servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp        0      0 172.24.0.8:1883         172.24.0.2:32836        ESTABLISHED -
tcp        0      0 172.24.0.8:41438        172.24.0.5:1883         ESTABLISHED -
tcp        0      0 172.24.0.8:33912        172.24.0.7:1883         TIME_WAIT   -


`http://localhost:18083/`
admin/public
`ws://localhost:8083/mqtt`