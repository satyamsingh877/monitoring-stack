cat > install.sh << 'EOF'
#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================="
echo "Jenkins-Prometheus-Grafana Stack Installer"
echo -e "=========================================${NC}\n"

# Check Docker
check_docker() {
    echo -e "${YELLOW}[1/6] Checking Docker...${NC}"
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker not found. Installing Docker...${NC}"
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        echo -e "${GREEN}✓ Docker installed${NC}"
    else
        echo -e "${GREEN}✓ Docker found${NC}"
    fi
}

# Start services
start_services() {
    echo -e "\n${YELLOW}[2/6] Starting Docker services...${NC}"
    docker-compose up -d
    echo -e "${GREEN}✓ Services started${NC}"
}

# Wait for Jenkins
wait_for_jenkins() {
    echo -e "\n${YELLOW}[3/6] Waiting for Jenkins to start (this takes 2-3 minutes)...${NC}"
    
    COUNTER=0
    while [ $COUNTER -lt 90 ]; do
        if curl -s http://localhost:8080 > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Jenkins is ready!${NC}"
            return 0
        fi
        echo -n "."
        sleep 2
        COUNTER=$((COUNTER + 1))
    done
    
    echo -e "\n${GREEN}✓ Jenkins service is running${NC}"
}

# Get Jenkins password
get_jenkins_password() {
    echo -e "\n${YELLOW}[4/6] Retrieving Jenkins initial password...${NC}"
    sleep 10
    
    PASSWORD=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null)
    
    if [ ! -z "$PASSWORD" ]; then
        echo -e "${GREEN}✓ Jenkins initial admin password retrieved${NC}"
        echo -e "\n${BLUE}========================================="
        echo "JENKINS INITIAL PASSWORD:"
        echo -e "${GREEN}$PASSWORD${NC}"
        echo -e "${BLUE}=========================================${NC}"
        
        # Save to file
        echo "$PASSWORD" > jenkins_password.txt
        echo -e "${YELLOW}Password saved to: jenkins_password.txt${NC}"
    else
        echo -e "${RED}Could not retrieve password. Check Jenkins logs:${NC}"
        echo "docker-compose logs jenkins"
    fi
}

# Check all services
check_services() {
    echo -e "\n${YELLOW}[5/6] Checking all services...${NC}"
    
    # Check Prometheus
    if curl -s http://localhost:9090 > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Prometheus: http://localhost:9090${NC}"
    else
        echo -e "${RED}✗ Prometheus not responding${NC}"
    fi
    
    # Check Grafana
    if curl -s http://localhost:3000 > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Grafana: http://localhost:3000 (admin/admin)${NC}"
    else
        echo -e "${RED}✗ Grafana not responding${NC}"
    fi
    
    # Check Node Exporter
    if curl -s http://localhost:9100 > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Node Exporter: http://localhost:9100${NC}"
    else
        echo -e "${RED}✗ Node Exporter not responding${NC}"
    fi
}

# Create monitoring script
create_monitoring_script() {
    echo -e "\n${YELLOW}[6/6] Creating monitoring scripts...${NC}"
    
    cat > monitor.sh << 'MONITOREOF'
#!/bin/bash

echo "=== Monitoring Stack Status ==="
echo ""
echo "Container Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "Service Health:"
echo -n "Jenkins:      "
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080

echo -n "Prometheus:   "
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:9090

echo -n "Grafana:      "
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3000

echo ""
echo "Jenkins Password:"
cat jenkins_password.txt 2>/dev/null || echo "Not found"

echo ""
echo "Quick Links:"
echo "  Jenkins:    http://localhost:8080"
echo "  Prometheus: http://localhost:9090"
echo "  Grafana:    http://localhost:3000"
MONITOREOF

    chmod +x monitor.sh
    
    # Create job monitoring script
    cat > job-monitor.sh << 'JOBSEOF'
#!/bin/bash

echo "=== Jenkins Jobs Monitoring ==="
echo ""

# Check if Prometheus has Jenkins metrics
METRICS=$(curl -s http://localhost:9090/api/v1/query?query=jenkins_job_last_build_result)

if echo "$METRICS" | grep -q "result"; then
    echo "✓ Jenkins metrics available in Prometheus"
    
    # Get total jobs
    TOTAL=$(curl -s 'http://localhost:9090/api/v1/query?query=count(jenkins_job_last_build_result)' | grep -oP '(?<="value":\[[^"]*",")[^"]*' || echo "0")
    echo "Total jobs monitored: $TOTAL"
    
    # Get failed jobs
    echo ""
    echo "Failed Jobs:"
    curl -s 'http://localhost:9090/api/v1/query?query=jenkins_job_last_build_result{result="FAILURE"}' | grep -oP '(?<=job_name":")[^"]*' || echo "  No failed jobs"
else
    echo "Waiting for Jenkins metrics to appear in Prometheus..."
    echo "Make sure Prometheus plugin is installed in Jenkins"
fi
JOBSEOF

    chmod +x job-monitor.sh
    echo -e "${GREEN}✓ Monitoring scripts created${NC}"
}

# Print final information
print_summary() {
    echo -e "\n${BLUE}========================================="
    echo -e "${GREEN}✓ INSTALLATION COMPLETE!${NC}"
    echo -e "${BLUE}=========================================${NC}\n"
    
    echo -e "${YELLOW}Access URLs:${NC}"
    echo -e "  📦 Jenkins:    ${GREEN}http://localhost:8080${NC}"
    echo -e "  📊 Prometheus: ${GREEN}http://localhost:9090${NC}"
    echo -e "  📈 Grafana:    ${GREEN}http://localhost:3000${NC}"
    
    echo -e "\n${YELLOW}Credentials:${NC}"
    echo -e "  Grafana:  ${GREEN}admin / admin${NC}"
    echo -e "  Jenkins:  ${GREEN}Use the initial password from jenkins_password.txt${NC}"
    
    echo -e "\n${YELLOW}Next Steps:${NC}"
    echo -e "  1. Open Jenkins and complete setup wizard"
    echo -e "  2. Install Prometheus plugin in Jenkins:"
    echo -e "     ${BLUE}Manage Jenkins → Manage Plugins → Available → Prometheus${NC}"
    echo -e "  3. Configure Prometheus plugin:"
    echo -e "     ${BLUE}Manage Jenkins → Configure System → Prometheus → Set path to /prometheus${NC}"
    echo -e "  4. Import Jenkins dashboard in Grafana:"
    echo -e "     ${BLUE}Dashboard ID: 9964 (Jenkins Performance Dashboard)${NC}"
    
    echo -e "\n${YELLOW}Useful Commands:${NC}"
    echo -e "  View logs:      ${BLUE}docker-compose logs -f${NC}"
    echo -e "  Check status:   ${BLUE}./monitor.sh${NC}"
    echo -e "  Monitor jobs:   ${BLUE}./job-monitor.sh${NC}"
    echo -e "  Stop stack:     ${BLUE}docker-compose down${NC}"
    echo -e "  Start stack:    ${BLUE}docker-compose up -d${NC}"
    
    echo -e "\n${BLUE}=========================================${NC}"
}

# Main execution
main() {
    check_docker
    start_services
    wait_for_jenkins
    get_jenkins_password
    check_services
    create_monitoring_script
    print_summary
}

main
EOF

chmod +x install.sh
