#!/bin/bash
# Fixed NiFi Registry permissions script

echo "🔧 Fixing NiFi Registry permissions..."

# Function to detect which Docker Compose version to use
detect_docker_compose() {
    if command -v docker compose &> /dev/null; then
        echo "docker compose"
    elif command -v docker-compose &> /dev/null; then
        # Reset environment variables that might cause issues
        unset DOCKER_HOST
        unset DOCKER_TLS_VERIFY 
        unset DOCKER_CERT_PATH
        echo "docker-compose"
    else
        echo "none"
    fi
}

COMPOSE_CMD=$(detect_docker_compose)

if [ "$COMPOSE_CMD" = "none" ]; then
    echo "❌ No Docker Compose found!"
    exit 1
fi

echo "📝 Using: $COMPOSE_CMD"

# Stop containers
echo "🛑 Stopping containers..."
$COMPOSE_CMD down 2>/dev/null || true

# Remove volumes to start fresh
echo "🧹 Cleaning up volumes..."
docker volume rm $(docker volume ls -q | grep nifi_registry) 2>/dev/null || true

# Get user ID
USER_ID=$(id -u)
GROUP_ID=$(id -g)

echo "📝 Using User ID: $USER_ID, Group ID: $GROUP_ID"

# Create updated docker-compose.yml with proper user mapping
echo "📝 Creating updated docker-compose.yml..."
cat > docker-compose.yml << 'COMPOSE_EOF'
version: '3.8'

services:
  # NiFi Registry
  nifi-registry:
    image: apache/nifi-registry:1.23.2
    container_name: nifi-registry
    restart: unless-stopped
    user: "1006:1006"
    ports:
      - "18080:18080"
    environment:
      - NIFI_REGISTRY_WEB_HTTP_PORT=18080
      - NIFI_REGISTRY_WEB_HTTP_HOST=0.0.0.0
    volumes:
      - nifi_registry_database:/opt/nifi-registry/nifi-registry-current/database
      - nifi_registry_flow_storage:/opt/nifi-registry/nifi-registry-current/flow_storage
      - nifi_registry_conf:/opt/nifi-registry/nifi-registry-current/conf
      - nifi_registry_logs:/opt/nifi-registry/nifi-registry-current/logs
    networks:
      - nifi-network

  # Apache NiFi
  nifi:
    image: apache/Nifi
    container_name: nifi
    restart: unless-stopped
    user: "1006:1006"
    ports:
      - "8443:8443"
      - "9090:8080"
    environment:
      - SINGLE_USER_CREDENTIALS_USERNAME=admin
      - SINGLE_USER_CREDENTIALS_PASSWORD=ctsBtRBKHRAx69EqUghvvgEvjnaLjFEB
      - NIFI_WEB_HTTPS_PORT=8443
      - NIFI_WEB_HTTP_PORT=8080
      - NIFI_WEB_PROXY_HOST=localhost:8443,localhost:9090
      - NIFI_REGISTRY_URL=http://nifi-registry:18080
    volumes:
      - nifi_database_repository:/opt/nifi/nifi-current/database_repository
      - nifi_flowfile_repository:/opt/nifi/nifi-current/flowfile_repository
      - nifi_content_repository:/opt/nifi/nifi-current/content_repository
      - nifi_provenance_repository:/opt/nifi/nifi-current/provenance_repository
      - nifi_state:/opt/nifi/nifi-current/state
      - nifi_conf:/opt/nifi/nifi-current/conf
      - nifi_logs:/opt/nifi/nifi-current/logs
    depends_on:
      - nifi-registry
    networks:
      - nifi-network

volumes:
  nifi_registry_database:
  nifi_registry_flow_storage:
  nifi_registry_conf:
  nifi_registry_logs:
  nifi_database_repository:
  nifi_flowfile_repository:
  nifi_content_repository:
  nifi_provenance_repository:
  nifi_state:
  nifi_conf:
  nifi_logs:

networks:
  nifi-network:
    driver: bridge
COMPOSE_EOF

# Update user IDs in the file
sed -i "s/1006:1006/$USER_ID:$GROUP_ID/g" docker-compose.yml

# Start services
echo "🚀 Starting services with proper permissions..."
$COMPOSE_CMD up -d

echo "⏳ Waiting for services to start..."
sleep 30

echo "📊 Checking status..."
$COMPOSE_CMD ps

echo "📝 Checking NiFi Registry logs..."
$COMPOSE_CMD logs nifi-registry --tail=10

echo ""
echo "🌐 Access URLs:"
echo "- NiFi Registry: http://localhost:18080"
echo "- NiFi Web UI: https://localhost:8443 (HTTPS)"
echo "- NiFi Web UI: http://localhost:9090 (HTTP)"
echo "- Credentials: admin / ctsBtRBKHRAx69EqUghvvgEvjnaLjFEB"
