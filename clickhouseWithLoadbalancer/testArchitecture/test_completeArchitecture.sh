#!/bin/bash
echo "=== Complete ClickHouse Cluster Architecture Test ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results tracking
tests_passed=0
tests_failed=0

run_test() {
    local test_name=$1
    local test_command=$2
    
    echo -e "\n${YELLOW}Testing: $test_name${NC}"
    
    if eval "$test_command"; then
        echo -e "${GREEN}✅ PASSED: $test_name${NC}"
        ((tests_passed++))
    else
        echo -e "${RED}❌ FAILED: $test_name${NC}"
        ((tests_failed++))
    fi
}

# Test 1: Container Health
run_test "Container Health" "docker ps | grep -E '(clickhouse01|clickhouse02|clickhouse-loadbalancer|zookeeper)' | wc -l | grep -q 4"

# Test 2: HAProxy Stats
run_test "HAProxy Stats Page" "curl -s http://localhost:8404/stats | grep -q 'HAProxy Statistics Report'"

# Test 3: Load Balancer HTTP
run_test "Load Balancer HTTP" "curl -s http://localhost:8120/ping | grep -q 'Ok'"

# Test 4: Direct ClickHouse Access
run_test "ClickHouse01 Direct" "curl -s http://localhost:8123/ping | grep -q 'Ok'"
run_test "ClickHouse02 Direct" "curl -s http://localhost:8124/ping | grep -q 'Ok'"

# Test 5: Database Operations
run_test "Database Creation" "curl -s -X POST 'http://localhost:8120/?query=CREATE DATABASE IF NOT EXISTS test_arch' | wc -c | grep -q 0"

# Test 6: Load Balancing
run_test "Load Balancing Distribution" "
    declare -A servers
    for i in {1..10}; do
        server=\$(curl -s 'http://localhost:8120/?query=SELECT hostname()' 2>/dev/null)
        servers[\$server]=1
    done
    [[ \${#servers[@]} -eq 2 ]]
"

# Test 7: Cluster Configuration
run_test "Cluster Configuration" "curl -s 'http://localhost:8120/?query=SELECT count() FROM system.clusters WHERE cluster='\''clickhouse_cluster'\''' | grep -q 2"

# Test 8: Zookeeper Connectivity
run_test "Zookeeper Connectivity" "curl -s 'http://localhost:8120/?query=SELECT * FROM system.zookeeper WHERE path='\''/'\'''' | wc -c | grep -v '^0$'"

# Final Results
echo -e "\n${YELLOW}=== TEST RESULTS ===${NC}"
echo -e "${GREEN}Tests Passed: $tests_passed${NC}"
echo -e "${RED}Tests Failed: $tests_failed${NC}"

if [ $tests_failed -eq 0 ]; then
    echo -e "\n${GREEN}🎉 ALL TESTS PASSED! Your ClickHouse cluster architecture is working perfectly!${NC}"
else
    echo -e "\n${RED}⚠️  Some tests failed. Please check the configuration.${NC}"
fi
