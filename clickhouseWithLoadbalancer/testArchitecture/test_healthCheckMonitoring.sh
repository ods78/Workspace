#!/bin/bash
echo "=== Health Check Monitoring ==="

# Monitor HAProxy stats for server status
check_server_status() {
    curl -s http://localhost:8404/stats | grep -E "(clickhouse01|clickhouse02)" | \
    awk -F',' '{print $1 ": " $18}' | sed 's/.*>//' | sed 's/<.*//'
}

echo "Current server status:"
check_server_status

echo -e "\nStopping clickhouse02 and monitoring status changes..."
docker stop clickhouse02

for i in {1..6}; do
    echo "Check $i (after ${i}0 seconds):"
    check_server_status
    sleep 10
done

echo -e "\nRestarting clickhouse02..."
docker start clickhouse02
