# monitors health of brokers

import paho.mqtt.client as mqtt
import json
import time
import os
import logging
from datetime import datetime

# Configure logging for the script
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class MQTTHealthChecker:
    def __init__(self):
        # List of brokers to check (name, host, port)
        self.brokers = [
            {'name': 'parent', 'host': 'mosquitto-parent', 'port': 1883},
            {'name': 'child1', 'host': 'mosquitto-child1', 'port': 1883},
            {'name': 'child2', 'host': 'mosquitto-child2', 'port': 1883}
        ]
        # Health status dictionary for each broker
        self.health_status = {
            'parent': {'healthy': False, 'last_check': None, 'response_time': None},
            'child1': {'healthy': False, 'last_check': None, 'response_time': None},
            'child2': {'healthy': False, 'last_check': None, 'response_time': None}
        }
        # Health check parameters (interval, timeout, fail threshold)
        self.check_interval = int(os.getenv('CHECK_INTERVAL', '10'))  # seconds
        self.timeout = int(os.getenv('TIMEOUT', '5'))  # seconds
        self.fail_threshold = int(os.getenv('FAIL_THRESHOLD', '3'))
        # File to write health status for nginx or other consumers
        self.health_status_file = '/health-status/status.json'

    def on_connect(self, client, userdata, flags, rc):
        # Callback for MQTT connection
        if rc == 0:
            logger.info(f"Connected to {userdata['name']} broker")
            # Send a ping by publishing to a test topic
            client.publish(f"health/{userdata['name']}/ping", "ping", qos=0)
            userdata['connected'] = True
            userdata['connect_time'] = time.time()
        else:
            logger.error(f"Failed to connect to {userdata['name']} broker: {rc}")
            userdata['connected'] = False

    def on_publish(self, client, userdata, mid):
        # Callback for successful publish (ping sent)
        userdata['ping_sent'] = True

    def on_message(self, client, userdata, msg):
        # Callback for received message (pong response)
        if msg.topic.startswith(f"health/{userdata['name']}/"):
            userdata['pong_received'] = True
            userdata['response_time'] = time.time() - userdata['connect_time']

    def check_broker_health(self, broker_info):
        """
        Check health of a single broker using MQTT ping.
        Connects, publishes a ping, and waits for a response.
        Updates self.health_status for the broker.
        """
        try:
            client = mqtt.Client(userdata={
                'name': broker_info['name'],
                'connected': False,
                'ping_sent': False,
                'pong_received': False,
                'connect_time': None,
                'response_time': None
            })

            client.on_connect = self.on_connect
            client.on_publish = self.on_publish
            client.on_message = self.on_message

            # Subscribe to health response topic
            client.subscribe(f"health/{broker_info['name']}/pong")

            # Attempt connection with timeout
            start_time = time.time()
            try:
                client.connect(broker_info['host'], broker_info['port'], keepalive=self.timeout)
                client.loop_start()

                # Wait for connection and ping response
                timeout_time = start_time + self.timeout
                while time.time() < timeout_time:
                    if client._userdata.get('connected') and client._userdata.get('ping_sent'):
                        # Wait a bit more for pong
                        time.sleep(0.5)
                        break
                    time.sleep(0.1)

                client.loop_stop()
                client.disconnect()

                # Determine health status
                connected = client._userdata.get('connected', False)
                response_time = client._userdata.get('response_time', None)

                if connected:
                    self.health_status[broker_info['name']] = {
                        'healthy': True,
                        'last_check': datetime.now().isoformat(),
                        'response_time': response_time,
                        'error': None
                    }
                    if response_time is not None:
                        logger.info(f"Broker {broker_info['name']} is healthy (response: {response_time:.3f}s)")
                    else:
                        logger.info(f"Broker {broker_info['name']} is healthy (response time unavailable)")
                    return True
                else:
                    raise Exception("Connection failed")

            except Exception as e:
                self.health_status[broker_info['name']] = {
                    'healthy': False,
                    'last_check': datetime.now().isoformat(),
                    'response_time': None,
                    'error': str(e)
                }
                logger.warning(f"Broker {broker_info['name']} health check failed: {e}")
                return False

        except Exception as e:
            logger.error(f"Health check error for {broker_info['name']}: {e}")
            self.health_status[broker_info['name']] = {
                'healthy': False,
                'last_check': datetime.now().isoformat(),
                'response_time': None,
                'error': str(e)
            }
            return False

    def update_health_status_file(self):
        """
        Write health status to file for nginx or other consumers.
        Determines the primary broker and writes a JSON status file.
        """
        try:
            os.makedirs(os.path.dirname(self.health_status_file), exist_ok=True)

            # Determine primary broker based on health priority
            primary_broker = None
            if self.health_status['parent']['healthy']:
                primary_broker = 'parent'
            elif self.health_status['child1']['healthy']:
                primary_broker = 'child1'
            elif self.health_status['child2']['healthy']:
                primary_broker = 'child2'

            status_data = {
                'timestamp': datetime.now().isoformat(),
                'primary_broker': primary_broker,
                'brokers': self.health_status,
                'overall_healthy': primary_broker is not None
            }

            with open(self.health_status_file, 'w') as f:
                json.dump(status_data, f, indent=2)

            logger.info(f"Health status updated - Primary: {primary_broker}")

        except Exception as e:
            logger.error(f"Failed to update health status file: {e}")

    def run(self):
        """
        Main health checking loop.
        Periodically checks all brokers and updates the health status file.
        """
        logger.info("Starting MQTT Health Checker")
        logger.info(f"Check interval: {self.check_interval}s, Timeout: {self.timeout}s")

        while True:
            try:
                logger.info("Running health checks...")

                # Check all brokers
                for broker in self.brokers:
                    self.check_broker_health(broker)

                # Update status file
                self.update_health_status_file()

                # Wait for next check
                time.sleep(self.check_interval)

            except KeyboardInterrupt:
                logger.info("Health checker stopped by user")
                break
            except Exception as e:
                logger.error(f"Health checker error: {e}")
                time.sleep(self.check_interval)


# Entry point for the script
if __name__ == "__main__":
    checker = MQTTHealthChecker()
    checker.run()