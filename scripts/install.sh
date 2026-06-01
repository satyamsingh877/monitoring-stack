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
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}Docker Compose not found. Installing...${NC}"
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        echo -e "${GREEN}Docker Compose installed successfully${NC}"
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

# Start the stack
start_stack() {
    echo -e "${YELLOW}Starting Docker stack...${NC}"
    docker-compose up -d
    
    echo -e "${YELLOW}Waiting for services to be ready...${NC}"
    sleep 30
    
    # Check service health
    if curl -s http://localhost:9090 > /dev/null; then
        echo -e "${GREEN}✓ Prometheus is running${NC}"
    else
        echo -e "${RED}✗ Prometheus failed to start${NC}"
    fi
    
    if curl -s http://localhost:3000 > /dev/null; then
        echo -e "${GREEN}✓ Grafana is running${NC}"
    else
        echo -e "${RED}✗ Grafana failed to start${NC}"
    fi
    
    if curl -s http://localhost:8080 > /dev/null; then
        echo -e "${GREEN}✓ Jenkins is running${NC}"
    else
        echo -e "${RED}✗ Jenkins failed to start${NC}"
    fi
}

# Setup Jenkins metrics
setup_jenkins_metrics() {
    echo -e "${YELLOW}Configuring Jenkins for Prometheus metrics...${NC}"
    
    # Wait for Jenkins to fully start
    sleep 60
    
    # Get initial admin password
    echo -e "${GREEN}Jenkins initial admin password:${NC}"
    docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "Check Jenkins logs"
    
    echo -e "${YELLOW}Please complete Jenkins setup at http://localhost:8080${NC}"
    echo -e "${YELLOW}Then install Prometheus plugin and configure:${NC}"
    echo "1. Go to Manage Jenkins → Manage Plugins → Available"
    echo "2. Search and install 'Prometheus' plugin"
    echo "3. Go to Manage Jenkins → Configure System → Prometheus"
    echo "4. Set 'Path' to '/prometheus'"
    echo "5. Apply and Save"
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
    echo -e "Next Steps:"
    echo "1. Configure Jenkins Prometheus plugin"
    echo "2. Import Jenkins dashboard in Grafana (ID: 9964)"
    echo "3. Create job-specific metrics collection"
    echo "========================================="
}

# Main execution
main() {
    check_prerequisites
    create_directories
    setup_prometheus
    setup_grafana
    setup_jenkins
    
    # Create docker-compose.yml if not exists
    if [ ! -f docker-compose.yml ]; then
        cat > docker-compose.yml << 'EOF'
# [Copy the docker-compose.yml content from above]
EOF
    fi
    
    start_stack
    setup_jenkins_metrics
    print_info
}

main
