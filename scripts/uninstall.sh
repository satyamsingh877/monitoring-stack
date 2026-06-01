#!/bin/bash

set -e

echo "========================================="
echo "Removing Jenkins-Prometheus-Grafana Stack"
echo "========================================="

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Stop and remove containers
echo -e "${YELLOW}Stopping Docker containers...${NC}"
docker-compose down -v

# Remove volumes
echo -e "${YELLOW}Removing Docker volumes...${NC}"
docker volume rm monitoring-stack_prometheus-data monitoring-stack_grafana-data 2>/dev/null || true

# Remove directories (optional)
read -p "Remove all configuration directories? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Removing directories...${NC}"
    rm -rf prometheus grafana jenkins scripts
    rm -f docker-compose.yml .env
    echo -e "${GREEN}✓ Directories removed${NC}"
fi

# Remove Docker images (optional)
read -p "Remove Docker images? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Removing Docker images...${NC}"
    docker rmi jenkins/jenkins:lts-jdk11 prom/prometheus:latest grafana/grafana:latest prom/node-exporter:latest 2>/dev/null || true
    echo -e "${GREEN}✓ Images removed${NC}"
fi

echo -e "${GREEN}✓ Stack removed successfully${NC}"
