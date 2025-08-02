#!/bin/bash
echo "=== Database Operations Test (POST Method) ==="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to check if command was successful
check_result() {
 local result="$1"
 local operation="$2"
 
 if [[ "$result" == *"Exception"* ]] || [[ "$result" == *"Error"* ]]; then
 echo -e "${RED}❌ $operation: FAILED${NC}"
 echo "Error: $result"
 return 1
 else
 echo -e "${GREEN}✅ $operation: SUCCESS${NC}"
 return 0
 fi
}

echo -e "${YELLOW}=== Step 1: Creating test database ===${NC}"
result=$(curl -s -X POST http://localhost:8120/ -d "CREATE DATABASE IF NOT EXISTS test_cluster" 2>&1)
if ! check_result "$result" "Database creation"; then
 echo "Stopping test due to database creation failure"
 exit 1
fi

# Verify database was created
echo "Verifying database exists..."
db_check=$(curl -s -X POST http://localhost:8120/ -d "SELECT name FROM system.databases WHERE name = 'test_cluster'" 2>&1)
if [[ "$db_check" == "test_cluster" ]]; then
 echo -e "${GREEN}✅ Database verification: SUCCESS${NC}"
else
 echo -e "${RED}❌ Database verification: FAILED${NC}"
 echo "Database check result: $db_check"
 exit 1
fi

echo -e "\n${YELLOW}=== Step 2: Creating test table ===${NC}"
result=$(curl -s -X POST http://localhost:8120/ -d "
CREATE TABLE IF NOT EXISTS test_cluster.test_table (
 id UInt32,
 server String,
 timestamp DateTime,
 data String
) ENGINE = MergeTree()
ORDER BY id
" 2>&1)

if ! check_result "$result" "Table creation"; then
 echo "Stopping test due to table creation failure"
 exit 1
fi

# Verify table was created
echo "Verifying table exists..."
table_check=$(curl -s -X POST http://localhost:8120/ -d "SELECT name FROM system.tables WHERE database = 'test_cluster' AND name = 'test_table'" 2>&1)
if [[ "$table_check" == "test_table" ]]; then
 echo -e "${GREEN}✅ Table verification: SUCCESS${NC}"
else
 echo -e "${RED}❌ Table verification: FAILED${NC}"
 echo "Table check result: $table_check"
 exit 1
fi

echo -e "\n${YELLOW}=== Step 3: Inserting test data ===${NC}"
success_count=0
for i in {1..10}; do
 result=$(curl -s -X POST http://localhost:8120/ -d "
 INSERT INTO test_cluster.test_table 
 VALUES ($i, hostname(), now(), 'test_data_$i')
 " 2>&1)
 
 if check_result "$result" "Insert record $i"; then
 ((success_count++))
 fi
done

echo "Successfully inserted $success_count out of 10 records"

echo -e "\n${YELLOW}=== Step 4: Querying data ===${NC}"
count=$(curl -s -X POST http://localhost:8120/ -d "SELECT count() FROM test_cluster.test_table" 2>&1)
if check_result "$count" "Data query"; then
 echo "Records found: $count"
else
 echo "Query failed: $count"
 exit 1
fi

echo -e "\n${YELLOW}=== Step 5: Testing load balancing with data ===${NC}"
echo "Querying from different servers to test load balancing..."
for i in {1..5}; do
 result=$(curl -s -X POST http://localhost:8120/ -d "
 SELECT 
 hostname() as server,
 count() as total_records
 FROM test_cluster.test_table
 " 2>&1)
 echo "Query $i result: $result"
done

echo -e "\n${YELLOW}=== Step 6: Testing individual server access ===${NC}"
echo "Testing ClickHouse01 direct access..."
count1=$(curl -s -X POST http://localhost:8123/ -d "SELECT count() FROM test_cluster.test_table" 2>&1)
echo "ClickHouse01 count: $count1"

echo "Testing ClickHouse02 direct access..."
count2=$(curl -s -X POST http://localhost:8124/ -d "SELECT count() FROM test_cluster.test_table" 2>&1)
echo "ClickHouse02 count: $count2"

echo -e "\n${YELLOW}=== Step 7: Testing cluster operations ===${NC}"
echo "Checking cluster configuration..."
cluster_info=$(curl -s -X POST http://localhost:8120/ -d "
SELECT 
 cluster,
 shard_num,
 replica_num,
 host_name
FROM system.clusters 
WHERE cluster = 'clickhouse_cluster'
" 2>&1)
echo "Cluster info: $cluster_info"

echo -e "\n${YELLOW}=== Step 8: Performance test ===${NC}"
echo "Running performance test..."
start_time=$(date +%s%3N)
for i in {1..20}; do
 curl -s -X POST http://localhost:8120/ -d "SELECT count() FROM test_cluster.test_table" >/dev/null 2>&1
done
end_time=$(date +%s%3N)
duration=$((end_time - start_time))
avg_time=$((duration / 20))
echo "20 queries completed in ${duration}ms (avg: ${avg_time}ms per query)"

echo -e "\n${YELLOW}=== Step 9: Cleanup ===${NC}"
echo "Cleaning up test data..."
curl -s -X POST http://localhost:8120/ -d "DROP TABLE IF EXISTS test_cluster.test_table" 2>&1
curl -s -X POST http://localhost:8120/ -d "DROP DATABASE IF EXISTS test_cluster" 2>&1
echo -e "${GREEN}✅ Cleanup completed${NC}"

echo -e "\n${GREEN}Database operations test completed successfully!${NC}"
