cat > uninstall.sh << 'EOF'
#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}========================================="
echo "Uninstalling Monitoring Stack"
echo -e "=========================================${NC}\n"

echo -e "${YELLOW}Stopping and removing containers...${NC}"
docker-compose down -v

echo -e "${YELLOW}Removing volumes...${NC}"
docker volume rm monitoring-stack_jenkins_home monitoring-stack_prometheus_data monitoring-stack_grafana_data 2>/dev/null

echo -e "${YELLOW}Removing networks...${NC}"
docker network rm monitoring-stack_monitoring-net 2>/dev/null

echo -e "${YELLOW}Cleaning up files...${NC}"
rm -f jenkins_password.txt monitor.sh job-monitor.sh

echo -e "\n${GREEN}✓ Uninstall complete${NC}"
echo -e "${YELLOW}To remove all Docker images as well:${NC}"
echo "  docker system prune -a"
EOF

chmod +x uninstall.sh
