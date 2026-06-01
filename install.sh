#!/bin/bash

set -e

echo "========================================="
echo "Jenkins-Prometheus-Grafana Stack Installer"
echo "========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker not found. Installing Docker...${NC}"
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        echo -e "${GREEN}Docker installed successfully${NC}"
    else
        echo -e "${GREEN}✓ Docker found${NC}"
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}Docker Compose not found. Installing...${NC}"
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        echo -e "${GREEN}Docker Compose installed successfully${NC}"
    else
        echo -e "${GREEN}✓ Docker Compose found${NC}"
    fi
    
    echo -e "${GREEN}✓ Prerequisites check completed${NC}"
}

# Create directory structure
create_directories() {
    echo -e "${YELLOW}Creating directory structure...${NC}"
    mkdir -p prometheus grafana/dashboards grafana/datasources jenkins/jenkins_home scripts
    echo -e "${GREEN}✓ Directories created${NC}"
}

# Setup Prometheus configuration
setup_prometheus() {
    echo -e "${YELLOW}Setting up Prometheus...${NC}"
    
    cat > prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'jenkins'
    metrics_path: '/prometheus'
    static_configs:
      - targets: ['jenkins:8080']
  
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
EOF

    cat > prometheus/alert.rules << 'EOF'
groups:
  - name: jenkins_alerts
    rules:
      - alert: JenkinsJobFailed
        expr: jenkins_job_last_build_result{result="FAILURE"} > 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Jenkins job {{ $labels.job_name }} failed"
EOF

    echo -e "${GREEN}✓ Prometheus configured${NC}"
}

# Setup Grafana datasources
setup_grafana() {
    echo -e "${YELLOW}Setting up Grafana...${NC}"
    
    cat > grafana/datasources/prometheus.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

    echo -e "${GREEN}✓ Grafana configured${NC}"
}

# Create Jenkins plugins list
setup_jenkins() {
    echo -e "${YELLOW}Setting up Jenkins...${NC}"
    
    cat > jenkins/plugins.txt << 'EOF'
prometheus:2.0.11
workflow-aggregator:590.v6a_d052e5a_a_b_5
git:5.2.0
build-metrics:1.3
metrics:4.2.21-442.v44e1b_8e12413
EOF

    echo -e "${GREEN}✓ Jenkins configured${NC}"
}

# Create docker-compose.yml
create_docker_compose() {
    echo -e "${YELLOW}Creating docker-compose.yml...${NC}"
    
    cat > docker-compose.yml << 'EOF'
version: '3.8'

networks:
  monitoring:
    driver: bridge

services:
  jenkins:
    image: jenkins/jenkins:lts-jdk11
    container_name: jenkins
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - ./jenkins/jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - JENKINS_OPTS=--prefix=/jenkins
    networks:
      - monitoring
    restart: unless-stopped

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    networks:
      - monitoring
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/dashboards:/etc/grafana/provisioning/dashboards
      - ./grafana/datasources:/etc/grafana/provisioning/datasources
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_INSTALL_PLUGINS=grafana-piechart-panel
    networks:
      - monitoring
    restart: unless-stopped

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--path.rootfs=/rootfs'
    networks:
      - monitoring
    restart: unless-stopped

volumes:
  prometheus-data:
  grafana-data:
EOF

    echo -e "${GREEN}✓ docker-compose.yml created${NC}"
}

# Start the stack
start_stack() {
    echo -e "${YELLOW}Starting Docker stack...${NC}"
    docker-compose up -d
    
    echo -e "${YELLOW}Waiting for services to be ready...${NC}"
    sleep 30
    
    # Check service health
    if curl -s http://localhost:9090 > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Prometheus is running${NC}"
    else
        echo -e "${RED}✗ Prometheus may still be starting${NC}"
    fi
    
    if curl -s http://localhost:3000 > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Grafana is running${NC}"
    else
        echo -e "${RED}✗ Grafana may still be starting${NC}"
    fi
    
    if curl -s http://localhost:8080 > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Jenkins is running${NC}"
    else
        echo -e "${RED}✗ Jenkins may still be starting${NC}"
    fi
}

# Setup Jenkins metrics
setup_jenkins_metrics() {
    echo -e "${YELLOW}Configuring Jenkins for Prometheus metrics...${NC}"
    
    # Wait for Jenkins to fully start
    echo -e "${YELLOW}Waiting for Jenkins to fully initialize (60 seconds)...${NC}"
    sleep 60
    
    # Get initial admin password
    echo -e "${GREEN}Jenkins initial admin password:${NC}"
    docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "Check Jenkins logs for password"
    
    echo ""
    echo -e "${YELLOW}IMPORTANT: Please complete Jenkins setup manually:${NC}"
    echo "1. Open http://localhost:8080 in your browser"
    echo "2. Use the initial admin password shown above"
    echo "3. Install suggested plugins or select custom"
    echo "4. Create admin user or continue as admin"
    echo "5. After Jenkins is ready, install Prometheus plugin:"
    echo "   - Go to Manage Jenkins → Manage Plugins → Available"
    echo "   - Search for 'Prometheus' and install"
    echo "   - Go to Manage Jenkins → Configure System → Prometheus"
    echo "   - Set 'Path' to '/prometheus'"
    echo "   - Enable 'Collect build metrics for all jobs'"
    echo "   - Click Save"
}

# Create monitoring script for 150+ jobs
create_monitoring_script() {
    echo -e "${YELLOW}Creating job monitoring script...${NC}"
    
    cat > scripts/monitor-jobs.sh << 'EOF'
#!/bin/bash

# Script to monitor Jenkins jobs through Prometheus

echo "=== Jenkins Jobs Monitoring ==="
echo ""

# Get total number of jobs
TOTAL_JOBS=$(curl -s 'http://localhost:9090/api/v1/query?query=count(jenkins_job_last_build_result)' | grep -oP '(?<="value":\[[^"]*",")[^"]*' || echo "0")
echo "Total monitored jobs: $TOTAL_JOBS"

# Get failed jobs
echo ""
echo "Failed Jobs:"
curl -s 'http://localhost:9090/api/v1/query?query=jenkins_job_last_build_result{result="FAILURE"}' | grep -oP '(?<=job_name":")[^"]*' || echo "No failed jobs found"

# Get build queue size
QUEUE_SIZE=$(curl -s 'http://localhost:9090/api/v1/query?query=jenkins_queue_size' | grep -oP '(?<="value":\[[^"]*",")[^"]*' || echo "0")
echo ""
echo "Build Queue Size: $QUEUE_SIZE"

# Get busy executors
BUSY_EXECUTORS=$(curl -s 'http://localhost:9090/api/v1/query?query=jenkins_executor_count_busy' | grep -oP '(?<="value":\[[^"]*",")[^"]*' || echo "0")
TOTAL_EXECUTORS=$(curl -s 'http://localhost:9090/api/v1/query?query=jenkins_executor_count_total' | grep -oP '(?<="value":\[[^"]*",")[^"]*' || echo "0")
echo "Executors: $BUSY_EXECUTORS/$TOTAL_EXECUTORS busy"
EOF

    chmod +x scripts/monitor-jobs.sh
    echo -e "${GREEN}✓ Monitoring script created${NC}"
}

# Print access information
print_info() {
    echo ""
    echo "========================================="
    echo -e "${GREEN}✓ Installation Complete!${NC}"
    echo "========================================="
    echo -e "Access URLs:"
    echo -e "  ${YELLOW}Jenkins:${NC}     http://localhost:8080"
    echo -e "  ${YELLOW}Prometheus:${NC}  http://localhost:9090"
    echo -e "  ${YELLOW}Grafana:${NC}     http://localhost:3000"
    echo ""
    echo -e "Default Credentials:"
    echo -e "  ${YELLOW}Grafana:${NC}     admin / admin"
    echo -e "  ${YELLOW}Jenkins:${NC}     Use initial admin password from above"
    echo ""
    echo -e "Useful Commands:"
    echo -e "  ${YELLOW}View logs:${NC}       docker-compose logs -f"
    echo -e "  ${YELLOW}Stop stack:${NC}      docker-compose down"
    echo -e "  ${YELLOW}Monitor jobs:${NC}    ./scripts/monitor-jobs.sh"
    echo ""
    echo -e "Next Steps for 150+ Jobs Monitoring:"
    echo "1. Complete Jenkins setup and install Prometheus plugin"
    echo "2. Import Grafana dashboard (ID: 9964 for Jenkins)"
    echo "3. Check metrics at http://localhost:8080/prometheus"
    echo "4. Run ./scripts/monitor-jobs.sh to see job status"
    echo "========================================="
}

# Main execution
main() {
    check_prerequisites
    create_directories
    setup_prometheus
    setup_grafana
    setup_jenkins
    create_docker_compose
    start_stack
    setup_jenkins_metrics
    create_monitoring_script
    print_info
}

main
