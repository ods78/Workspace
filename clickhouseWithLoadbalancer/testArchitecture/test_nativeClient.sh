#!/bin/bash
echo "=== Native TCP Protocol Test ==="

# Test if clickhouse-client is available
if ! command -v clickhouse-client &> /dev/null; then
    echo "Installing clickhouse-client..."
    # Ubuntu/Debian
    sudo apt-get update && sudo apt-get install -y clickhouse-client
    # Or for CentOS/RHEL: sudo yum install -y clickhouse-client
fi

echo "1. Testing direct connection to ClickHouse01:"
clickhouse-client --host localhost --port 8003 --query "SELECT 'Direct CH01' as connection, hostname()"

echo "2. Testing direct connection to ClickHouse02:"
clickhouse-client --host localhost --port 8004 --query "SELECT 'Direct CH02' as connection, hostname()"

echo "3. Testing load-balanced native connection:"
clickhouse-client --host localhost --port 8010 --query "SELECT 'Load Balanced' as connection, hostname()"

# Test multiple connections through load balancer
echo "4. Testing native load balancing:"
for i in {1..5}; do
    result=$(clickhouse-client --host localhost --port 8010 --query "SELECT $i as request, hostname() as server")
    echo "Request $i: $result"
done
