#!/bin/bash
echo "=== High Availability Failover Test ==="

# Function to test connectivity
test_connectivity() {
    curl -s "http://localhost:8120/?query=SELECT 'OK' as status, hostname() as server" 2>/dev/null || echo "FAILED"
}

echo "1. Testing normal operation..."
test_connectivity

echo -e "\n2. Stopping ClickHouse01..."
docker stop clickhouse01
sleep 5

echo "3. Testing failover to ClickHouse02..."
for i in {1..5}; do
    result=$(test_connectivity)
    echo "Test $i: $result"
done

echo -e "\n4. Restarting ClickHouse01..."
docker start clickhouse01
sleep 10

echo "5. Testing recovery..."
for i in {1..5}; do
    result=$(test_connectivity)
    echo "Test $i: $result"
done
