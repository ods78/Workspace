#!/bin/bash
echo "=== Concurrent Load Test ==="

# Function to make requests
make_request() {
    local id=$1
    local result=$(curl -s "http://localhost:8120/?query=SELECT $id as request_id, hostname() as server, now() as timestamp")
    echo "Request $id: $result"
}

# Run 10 concurrent requests
for i in {1..10}; do
    make_request $i &
done

wait
echo "All concurrent requests completed"
