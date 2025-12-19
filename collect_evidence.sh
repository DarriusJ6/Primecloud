#!/bin/bash
# Proxmox runs as root and does not include sudo
if command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
else
  SUDO=""
fi
################################################################################
# PrimeCloud Evidence Collection Script
# Purpose: Automate collection of command outputs and configs for portfolio
# Usage: ./collect_evidence.sh [service_name]
# Examples:
#   ./collect_evidence.sh all        # Collect from all services
#   ./collect_evidence.sh proxmox    # Collect only Proxmox evidence
#   ./collect_evidence.sh hardware   # Collect only hardware info
################################################################################

set -e  # Exit on error

# Configuration
BASE_DIR="${HOME}/primecloud-portfolio"
EVIDENCE_DIR="${BASE_DIR}/evidence"
CONFIGS_DIR="${BASE_DIR}/configs"
DATE=$(date +%Y%m%d)

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Ensure directories exist
ensure_dirs() {
    mkdir -p "${EVIDENCE_DIR}"/{hardware,proxmox,network,opnsense,traefik,auth,database,vault,monitoring}
    mkdir -p "${CONFIGS_DIR}"/{proxmox,opnsense,traefik,keycloak,postgres,vaultwarden,monitoring}
}

# Hardware Evidence Collection
collect_hardware() {
    log_info "Collecting hardware evidence..."
    
    # CPU info
    lscpu | grep -E 'Model name|CPU\(s\)|Thread|Socket' > "${EVIDENCE_DIR}/hardware/cpu-info-${DATE}.txt"
    log_success "CPU info collected"
    
    # Memory info
    free -h > "${EVIDENCE_DIR}/hardware/memory-info-${DATE}.txt"
    log_success "Memory info collected"
    
    # Disk layout
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT > "${EVIDENCE_DIR}/hardware/disk-layout-${DATE}.txt"
    log_success "Disk layout collected"
    
    # Network interfaces
    ip link show > "${EVIDENCE_DIR}/hardware/network-interfaces-${DATE}.txt"
    log_success "Network interfaces collected"
    
    # System DMI info
    if command -v dmidecode &> /dev/null; then
        $SUDO dmidecode -t system | grep -A 10 'System Information' > "${EVIDENCE_DIR}/hardware/system-dmidecode-${DATE}.txt"
        log_success "DMI system info collected"
    else
        log_warning "dmidecode not found, skipping system DMI info"
    fi
}

# Proxmox Evidence Collection
collect_proxmox() {
    log_info "Collecting Proxmox evidence..."
    
    # Version info
    pveversion -v > "${EVIDENCE_DIR}/proxmox/pve-version-${DATE}.txt"
    log_success "Proxmox version collected"
    
    # Storage status
    pvesm status > "${EVIDENCE_DIR}/proxmox/storage-status-${DATE}.txt"
    log_success "Storage status collected"
    
    # Storage config
    cp /etc/pve/storage.cfg "${EVIDENCE_DIR}/proxmox/storage-config-${DATE}.txt"
    log_success "Storage config collected"
    
    # Disk usage
    df -h > "${EVIDENCE_DIR}/proxmox/disk-usage-${DATE}.txt"
    log_success "Disk usage collected"
    
    # Network interfaces config
    cp /etc/network/interfaces "${EVIDENCE_DIR}/proxmox/network-interfaces-${DATE}.txt"
    log_success "Network interfaces collected"
    
    # VM/CT inventory
    pvesh get /cluster/resources --type vm --output-format json-pretty > "${EVIDENCE_DIR}/proxmox/vm-inventory-${DATE}.json"
    log_success "VM inventory collected"
    
    # Copy configs to configs directory (sanitized versions)
    log_info "Copying configs to ${CONFIGS_DIR}/proxmox (remember to sanitize!)"
    cp /etc/network/interfaces "${CONFIGS_DIR}/proxmox/network-interfaces"
    cp /etc/pve/storage.cfg "${CONFIGS_DIR}/proxmox/storage.cfg"
    log_warning "⚠️  Remember to redact sensitive IPs from configs!"
}

# Network Evidence Collection
collect_network() {
    log_info "Collecting network evidence..."
    
    # Bridge VLAN info
    if command -v bridge &> /dev/null; then
        bridge vlan show > "${EVIDENCE_DIR}/network/bridge-vlan-show-${DATE}.txt"
        log_success "Bridge VLAN info collected"
    else
        log_warning "bridge command not found"
    fi
    
    # vmbr0 details
    ip link show vmbr0 > "${EVIDENCE_DIR}/network/vmbr0-details-${DATE}.txt" 2>/dev/null || log_warning "vmbr0 not found"
    log_success "Network bridge details collected"
}

# PostgreSQL Evidence Collection
collect_postgres() {
    log_info "Collecting PostgreSQL evidence..."
    
    # Check if running in Docker
    if docker ps | grep -q postgres; then
        POSTGRES_CONTAINER=$(docker ps --filter "name=postgres" --format "{{.Names}}" | head -1)
        log_info "Found PostgreSQL container: ${POSTGRES_CONTAINER}"
        
        # Database list
        docker exec "${POSTGRES_CONTAINER}" psql -U postgres -c '\l' > "${EVIDENCE_DIR}/database/database-list-${DATE}.txt"
        log_success "Database list collected"
        
        # PostgreSQL version
        docker exec "${POSTGRES_CONTAINER}" psql -U postgres -c 'SELECT version();' > "${EVIDENCE_DIR}/database/postgres-version-${DATE}.txt"
        log_success "PostgreSQL version collected"
        
        # Container status
        docker ps | grep postgres > "${EVIDENCE_DIR}/database/container-status-${DATE}.txt"
        log_success "Container status collected"
    else
        log_warning "PostgreSQL container not found, skipping database evidence"
    fi
}

# Traefik Evidence Collection
collect_traefik() {
    log_info "Collecting Traefik evidence..."
    
    # Check if running in Docker
    if docker ps | grep -q traefik; then
        TRAEFIK_CONTAINER=$(docker ps --filter "name=traefik" --format "{{.Names}}" | head -1)
        log_info "Found Traefik container: ${TRAEFIK_CONTAINER}"
        
        # Container status
        docker ps | grep traefik > "${EVIDENCE_DIR}/traefik/container-status-${DATE}.txt"
        log_success "Container status collected"
        
        # Recent logs
        docker logs "${TRAEFIK_CONTAINER}" --tail 100 > "${EVIDENCE_DIR}/traefik/recent-logs-${DATE}.txt"
        log_success "Recent logs collected"
        
        log_warning "⚠️  Remember to manually export docker-compose.yml and configs"
        log_warning "⚠️  DO NOT copy acme.json - it contains private keys!"
    else
        log_warning "Traefik container not found, skipping Traefik evidence"
    fi
}

# Monitoring Evidence Collection
collect_monitoring() {
    log_info "Collecting monitoring evidence..."
    
    # Prometheus
    if docker ps | grep -q prometheus; then
        PROM_CONTAINER=$(docker ps --filter "name=prometheus" --format "{{.Names}}" | head -1)
        docker ps | grep prometheus > "${EVIDENCE_DIR}/monitoring/prometheus-status-${DATE}.txt"
        log_success "Prometheus status collected"
    fi
    
    # Grafana
    if docker ps | grep -q grafana; then
        GRAFANA_CONTAINER=$(docker ps --filter "name=grafana" --format "{{.Names}}" | head -1)
        docker ps | grep grafana > "${EVIDENCE_DIR}/monitoring/grafana-status-${DATE}.txt"
        log_success "Grafana status collected"
    fi
}

# Summary Report
generate_summary() {
    log_info "Generating collection summary..."
    
    SUMMARY_FILE="${EVIDENCE_DIR}/COLLECTION_SUMMARY_${DATE}.txt"
    
    cat > "${SUMMARY_FILE}" << EOF
PrimeCloud Evidence Collection Summary
======================================
Date: ${DATE}
Time: $(date +%H:%M:%S)

Files Collected:
EOF
    
    find "${EVIDENCE_DIR}" -type f -name "*${DATE}*" | while read -r file; do
        echo "  - ${file}" >> "${SUMMARY_FILE}"
    done
    
    echo "" >> "${SUMMARY_FILE}"
    echo "Next Steps:" >> "${SUMMARY_FILE}"
    echo "  1. Review all collected files" >> "${SUMMARY_FILE}"
    echo "  2. Sanitize configs in ${CONFIGS_DIR}" >> "${SUMMARY_FILE}"
    echo "  3. Take screenshots as per documentation guide" >> "${SUMMARY_FILE}"
    echo "  4. Create architecture diagrams" >> "${SUMMARY_FILE}"
    echo "  5. Write narrative documentation" >> "${SUMMARY_FILE}"
    
    log_success "Summary generated: ${SUMMARY_FILE}"
    cat "${SUMMARY_FILE}"
}

# Main execution
main() {
    local service="${1:-all}"
    
    log_info "Starting PrimeCloud evidence collection..."
    log_info "Service: ${service}"
    
    ensure_dirs
    
    case "${service}" in
        all)
            collect_hardware
            collect_proxmox
            collect_network
            collect_postgres
            collect_traefik
            collect_monitoring
            ;;
        hardware)
            collect_hardware
            ;;
        proxmox)
            collect_proxmox
            ;;
        network)
            collect_network
            ;;
        postgres|database)
            collect_postgres
            ;;
        traefik)
            collect_traefik
            ;;
        monitoring)
            collect_monitoring
            ;;
        *)
            log_error "Unknown service: ${service}"
            echo "Usage: $0 {all|hardware|proxmox|network|postgres|traefik|monitoring}"
            exit 1
            ;;
    esac
    
    generate_summary
    
    log_success "Evidence collection complete!"
    log_info "Evidence stored in: ${EVIDENCE_DIR}"
    log_info "Configs stored in: ${CONFIGS_DIR}"
    log_warning "⚠️  REMEMBER: Review and sanitize all files before committing to Git!"
}

# Run main function
main "$@"
