#!/bin/bash
echo "=== Performance Consistency Test ==="

# Function to measure query time
measure_query_time() {
    local endpoint=$1
    local description=$2
    
    echo "Testing $description..."
    
    for i in {1..5}; do
        start_time=$(date +%s%3N)
        curl -s "$endpoint/?query=SELECT count() FROM system.numbers LIMIT 1000000" > /dev/null
        end_time=$(date +%s%3N)
        
        duration=$((end_time - start_time))
        echo "  Run $i: ${duration}ms"
    done
}

# Test direct connections
measure_query_time "http://localhost:8123" "ClickHouse01 Direct"
measure_query_time "http://localhost:8124" "ClickHouse02 Direct"
measure_query_time "http://localhost:8120" "Load Balanced"
