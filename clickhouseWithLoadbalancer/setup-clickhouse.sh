#!/bin/bash

# ClickHouse Cluster Setup Script
echo "Setting up ClickHouse cluster with HAProxy load balancer..."

# Create necessary directories
echo "Creating directories..."
mkdir -p {zookeeper-data,zookeeper-datalog,clickhouse01-data,clickhouse01-logs,clickhouse02-data,clickhouse02-logs,config}

# Create the external network
echo "Creating external network..."
docker network create clickhouse_net 2>/dev/null || echo "Network already exists"

# Create ClickHouse configuration for node 01
echo "Creating ClickHouse configuration files..."
cat > config/clickhouse01-config.xml << 'EOF'
<yandex>
    <logger>
        <level>information</level>
        <log>/var/log/clickhouse-server/clickhouse-server.log</log>
        <errorlog>/var/log/clickhouse-server/clickhouse-server.err.log</errorlog>
        <size>1000M</size>
        <count>10</count>
    </logger>

    <http_port>8123</http_port>
    <tcp_port>9000</tcp_port>
    <mysql_port>9004</mysql_port>
    <postgresql_port>9005</postgresql_port>

    <listen_host>::</listen_host>
    <listen_host>0.0.0.0</listen_host>

    <max_connections>4096</max_connections>
    <keep_alive_timeout>3</keep_alive_timeout>
    <max_concurrent_queries>100</max_concurrent_queries>
    <uncompressed_cache_size>8589934592</uncompressed_cache_size>
    <mark_cache_size>5368709120</mark_cache_size>

    <path>/var/lib/clickhouse/</path>
    <tmp_path>/var/lib/clickhouse/tmp/</tmp_path>
    <user_files_path>/var/lib/clickhouse/user_files/</user_files_path>
    <users_config>users.xml</users_config>
    <default_profile>default</default_profile>
    <default_database>default</default_database>

    <zookeeper>
        <node index="1">
            <host>zookeeper</host>
            <port>2181</port>
        </node>
    </zookeeper>

    <macros>
        <cluster>clickhouse_cluster</cluster>
        <shard>01</shard>
        <replica>clickhouse01</replica>
    </macros>

    <remote_servers>
        <clickhouse_cluster>
            <shard>
                <replica>
                    <host>clickhouse01</host>
                    <port>9000</port>
                </replica>
                <replica>
                    <host>clickhouse02</host>
                    <port>9000</port>
                </replica>
            </shard>
        </clickhouse_cluster>
    </remote_servers>

    <distributed_ddl>
        <path>/clickhouse/task_queue/ddl</path>
    </distributed_ddl>
</yandex>
EOF

# Create ClickHouse configuration for node 02
cat > config/clickhouse02-config.xml << 'EOF'
<yandex>
    <logger>
        <level>information</level>
        <log>/var/log/clickhouse-server/clickhouse-server.log</log>
        <errorlog>/var/log/clickhouse-server/clickhouse-server.err.log</errorlog>
        <size>1000M</size>
        <count>10</count>
    </logger>

    <http_port>8123</http_port>
    <tcp_port>9000</tcp_port>
    <mysql_port>9004</mysql_port>
    <postgresql_port>9005</postgresql_port>

    <listen_host>::</listen_host>
    <listen_host>0.0.0.0</listen_host>

    <max_connections>4096</max_connections>
    <keep_alive_timeout>3</keep_alive_timeout>
    <max_concurrent_queries>100</max_concurrent_queries>
    <uncompressed_cache_size>8589934592</uncompressed_cache_size>
    <mark_cache_size>5368709120</mark_cache_size>

    <path>/var/lib/clickhouse/</path>
    <tmp_path>/var/lib/clickhouse/tmp/</tmp_path>
    <user_files_path>/var/lib/clickhouse/user_files/</user_files_path>
    <users_config>users.xml</users_config>
    <default_profile>default</default_profile>
    <default_database>default</default_database>

    <zookeeper>
        <node index="1">
            <host>zookeeper</host>
            <port>2181</port>
        </node>
    </zookeeper>

    <macros>
        <cluster>clickhouse_cluster</cluster>
        <shard>01</shard>
        <replica>clickhouse02</replica>
    </macros>

    <remote_servers>
        <clickhouse_cluster>
            <shard>
                <replica>
                    <host>clickhouse01</host>
                    <port>9000</port>
                </replica>
                <replica>
                    <host>clickhouse02</host>
                    <port>9000</port>
                </replica>
            </shard>
        </clickhouse_cluster>
    </remote_servers>

    <distributed_ddl>
        <path>/clickhouse/task_queue/ddl</path>
    </distributed_ddl>
</yandex>
EOF

# Create users configuration
cat > config/users.xml << 'EOF'
<yandex>
    <profiles>
        <default>
            <max_memory_usage>10000000000</max_memory_usage>
            <use_uncompressed_cache>0</use_uncompressed_cache>
            <load_balancing>random</load_balancing>
        </default>
        <readonly>
            <readonly>1</readonly>
        </readonly>
    </profiles>

    <users>
        <default>
            <password></password>
            <networks incl="networks" replace="replace">
                <ip>::/0</ip>
            </networks>
            <profile>default</profile>
            <quota>default</quota>
        </default>
        
        <admin>
            <password>admin123</password>
            <networks incl="networks" replace="replace">
                <ip>::/0</ip>
            </networks>
            <profile>default</profile>
            <quota>default</quota>
            <access_management>1</access_management>
        </admin>
    </users>

    <quotas>
        <default>
            <interval>
                <duration>3600</duration>
                <queries>0</queries>
                <errors>0</errors>
                <result_rows>0</result_rows>
                <read_rows>0</read_rows>
                <execution_time>0</execution_time>
            </interval>
        </default>
    </quotas>
</yandex>
EOF

# Create HAProxy configuration
cat > haproxy.cfg << 'EOF'
global
    daemon
    log stdout local0
    maxconn 4096
    stats socket /var/run/haproxy.sock mode 660 level admin
    stats timeout 30s

defaults
    mode http
    log global
    option httplog
    option dontlognull
    option log-health-checks
    option forwardfor
    option http-server-close
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms
    errorfile 400 /usr/local/etc/haproxy/errors/400.http
    errorfile 403 /usr/local/etc/haproxy/errors/403.http
    errorfile 408 /usr/local/etc/haproxy/errors/408.http
    errorfile 500 /usr/local/etc/haproxy/errors/500.http
    errorfile 502 /usr/local/etc/haproxy/errors/502.http
    errorfile 503 /usr/local/etc/haproxy/errors/503.http
    errorfile 504 /usr/local/etc/haproxy/errors/504.http

# Stats page
frontend stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 30s
    stats admin if TRUE

# HTTP interface load balancer
frontend clickhouse_http
    bind *:8123
    default_backend clickhouse_http_servers

backend clickhouse_http_servers
    balance roundrobin
    option httpchk GET /ping
    http-check expect status 200
    server clickhouse01 clickhouse01:8123 check
    server clickhouse02 clickhouse02:8123 check

# Native TCP interface load balancer
frontend clickhouse_native
    mode tcp
    bind *:9000
    default_backend clickhouse_native_servers

backend clickhouse_native_servers
    mode tcp
    balance roundrobin
    option tcp-check
    server clickhouse01 clickhouse01:9000 check
    server clickhouse02 clickhouse02:9000 check
EOF

# Set proper permissions
echo "Setting permissions..."
chmod -R 755 zookeeper-data zookeeper-datalog clickhouse01-data clickhouse01-logs clickhouse02-data clickhouse02-logs config
chmod 644 haproxy.cfg config/*.xml

echo "Setup completed successfully!"
echo ""
echo "Directory structure created:"
echo "├── zookeeper-data/"
echo "├── zookeeper-datalog/"
echo "├── clickhouse01-data/"
echo "├── clickhouse01-logs/"
echo "├── clickhouse02-data/"
echo "├── clickhouse02-logs/"
echo "├── config/"
echo "│   ├── clickhouse01-config.xml"
echo "│   ├── clickhouse02-config.xml"
echo "│   └── users.xml"
echo "└── haproxy.cfg"
echo ""
echo "Network 'clickhouse_net' created/verified"
echo ""
echo "You can now run: docker-compose up -d"
echo ""
echo "Access points after startup:"
echo "- ClickHouse HTTP (load balanced): http://localhost:8120"
echo "- ClickHouse Native (load balanced): localhost:8010"
echo "- HAProxy Stats: http://localhost:8404/stats"
echo "- Direct ClickHouse01 HTTP: http://localhost:8123"
echo "- Direct ClickHouse02 HTTP: http://localhost:8124"
echo ""
echo "Default credentials:"
echo "- User: default (no password)"
echo "- Admin user: admin, password: admin123"
EOF
