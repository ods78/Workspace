#!/bin/bash
echo "=== Load Balancing Test (POST Method) ==="

# Test load distribution
declare -A server_count
total_requests=20

echo "Making $total_requests requests to test load distribution..."

for i in $(seq 1 $total_requests); do
    hostname=$(curl -s -X POST http://localhost:8120/ -d "SELECT hostname()" 2>/dev/null)
    if [[ -n "$hostname" ]]; then
        server_count[$hostname]=$((${server_count[$hostname]} + 1))
        echo "Request $i: $hostname"
    else
        echo "Request $i: FAILED"
    fi
done

echo -e "\n=== Load Distribution Results ==="
for server in "${!server_count[@]}"; do
    percentage=$(( server_count[$server] * 100 / total_requests ))
    echo "$server: ${server_count[$server]} requests (${percentage}%)"
done
