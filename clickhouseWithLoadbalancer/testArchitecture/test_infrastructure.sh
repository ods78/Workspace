#!/bin/bash
echo "=== High Availability Test ==="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to test connectivity
test_connectivity() {
    local result=$(curl -s "http://localhost:8120/?query=SELECT 'OK' as status, hostname() as server" 2>/dev/null)
    if [[ -n "$result" ]]; then
        echo "$result"
        return 0
    else
        echo "FAILED"
        return 1
    fi
}

# Function to check server status in HAProxy
check_haproxy_status() {
    curl -s http://localhost:8404/stats | grep -E "(clickhouse01|clickhouse02)" | \
    awk -F',' '{print $1 ": " $18}' | sed 's/.*>//' | sed 's/<.*//'
}

echo -e "${YELLOW}=== Initial Status Check ===${NC}"
echo "HAProxy server status:"
check_haproxy_status

echo -e "\nTesting normal operation..."
result=$(test_connectivity)
echo "Normal operation result: $result"

echo -e "\n${YELLOW}=== Failover Test (Stopping ClickHouse01) ===${NC}"
echo "Stopping ClickHouse01..."
docker stop clickhouse01
sleep 5

echo "Testing failover to ClickHouse02..."
for i in {1..5}; do
    result=$(test_connectivity)
    echo "Failover test $i: $result"
    sleep 2
done

echo -e "\nHAProxy status after ClickHouse01 failure:"
check_haproxy_status

echo -e "\n${YELLOW}=== Recovery Test (Restarting ClickHouse01) ===${NC}"
echo "Restarting ClickHouse01..."
docker start clickhouse01
echo "Waiting for ClickHouse01 to become ready..."
sleep 25

echo "Testing recovery..."
for i in {1..5}; do
    result=$(test_connectivity)
    echo "Recovery test $i: $result"
    sleep 2
done

echo -e "\nHAProxy status after ClickHouse01 recovery:"
check_haproxy_status

echo -e "\n${YELLOW}=== Failover Test (Stopping ClickHouse02) ===${NC}"
echo "Stopping ClickHouse02..."
docker stop clickhouse02
sleep 5

echo "Testing failover to ClickHouse01..."
for i in {1..5}; do
    result=$(test_connectivity)
    echo "Failover test $i: $result"
    sleep 2
done

echo -e "\n${YELLOW}=== Full Recovery ===${NC}"
echo "Restarting ClickHouse02..."
docker start clickhouse02
echo "Waiting for ClickHouse02 to become ready..."
sleep 25

echo "Testing full cluster recovery..."
declare -A recovery_servers
for i in {1..10}; do
    server=$(curl -s "http://localhost:8120/?query=SELECT hostname()" 2>/dev/null)
    if [[ -n "$server" ]]; then
        recovery_servers[$server]=1
    fi
done

if [[ ${#recovery_servers[@]} -eq 2 ]]; then
    echo -e "${GREEN}✅ Full cluster recovery successful - both servers active${NC}"
else
    echo -e "${RED}❌ Cluster recovery incomplete${NC}"
fi

echo -e "\nFinal HAProxy status:"
check_haproxy_status

echo -e "\n${GREEN}High availability test completed!${NC}"
