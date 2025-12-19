 HEAD
# PrimeCloud

> A modular, security-first private cloud platform built on Proxmox VE with VLAN-segmented networking and centralized authentication

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Status](https://img.shields.io/badge/status-production-success)
![Platform](https://img.shields.io/badge/platform-Proxmox%20VE-orange)

---

## Overview

PrimeCloud is a production-grade private cloud infrastructure designed to host containerized services with enterprise-level isolation, centralized authentication, and comprehensive observability. The platform runs on a Dell PowerEdge R630 server using Proxmox VE as the hypervisor, with network segmentation enforced through VLANs and a dedicated OPNsense firewall.

The architecture prioritizes security through defense-in-depth, separating management, edge, backend services, and application workloads into distinct network zones. All external traffic flows through a reverse proxy with TLS termination, followed by authentication enforcement before reaching internal services. The infrastructure is designed for reproducibility, with configuration files, deployment scripts, and comprehensive documentation supporting infrastructure-as-code principles.

This project demonstrates practical expertise in virtualization, network engineering, containerization, identity management, and systems architecture, built entirely from bare metal through to operational monitoring.

---

## Architecture

![Network Architecture](diagrams/primecloud-network-architecture-v1.svg)

![Service Flow](diagrams/primecloud-service-flow-v1.svg)

![Security Zones](diagrams/primecloud-security-zones-v1.svg)

---

## Technology Stack

### Hardware & Virtualization
- **Physical Host:** Dell PowerEdge R630 (2x Xeon CPUs, 128GB RAM, RAID storage)
- **Hypervisor:** Proxmox VE 9.0.10 (KVM/QEMU + LXC containers)
- **Network Switch:** TP-Link 8-port Gigabit managed switch with 802.1Q VLAN support

### Networking & Security
- **Firewall/Router:** OPNsense (stateful firewall, IDS/IPS-ready, DNS resolver)
- **Network Segmentation:** 5 VLANs (Management, DMZ, Services, Apps, Lab)
- **Reverse Proxy:** Traefik v3 (automatic TLS via Let's Encrypt HTTP-01, dynamic routing)

### Identity & Access
- **Authentication Gateway:** Authelia (2FA support, session management, LDAP-ready)
- **Secrets Management:** Vaultwarden (Bitwarden-compatible password vault)

### Data & Storage
- **Database:** PostgreSQL 16 (dedicated container, automated backups)
- **Version Control:** Gitea (self-hosted Git with CI/CD integration)
- **Backup Repository:** Restic (encrypted, deduplicated backup storage)

### Observability
- **Metrics Collection:** Prometheus (multi-target scraping, 30-day retention)
- **Visualization:** Grafana (custom dashboards, alerting integration)
- **CI/CD Pipeline:** Woodpecker CI (lightweight, container-native)

---

## Key Features

### Security-First Design
- **Network isolation** with VLAN segmentation and firewall-enforced routing
- **Zero-trust authentication** enforced at the edge via forward-auth middleware
- **TLS encryption** for all external connections with automatic certificate management
- **Minimal attack surface** with containerized services and restricted inter-VLAN traffic

### Modularity & Reproducibility
- **Infrastructure-as-code ready** with version-controlled configurations
- **Container-native services** using LXC for efficiency and isolation
- **Centralized database** with logical separation per service
- **Documented deployment procedures** with sanitized configuration examples

### Observability & Operations
- **Comprehensive metrics collection** across all infrastructure components
- **Custom Grafana dashboards** for infrastructure and application monitoring
- **Centralized logging architecture** (log aggregation ready)
- **Backup strategy** with automated snapshots and off-host storage

### Practical Scale
- **Single-node deployment** optimized for home lab/SMB use cases
- **Designed for growth** with clear expansion paths (HA clustering, geographic redundancy)
- **Resource-efficient** using LXC containers where appropriate
- **Production-ready** with documented runbooks and disaster recovery procedures

---

## Documentation

### Technical Documentation
- [Technical Deep Dive](docs/technical-overview.md) - Architecture decisions and system design
- [Build Timeline](docs/build-timeline.md) - Project phases and time investment
- [Lessons Learned](docs/lessons-learned.md) - Challenges, mistakes, and improvements

### Operational Documentation
- [Runbooks](runbooks/) - Standard operating procedures and troubleshooting guides
- [Configuration Examples](configs/) - Sanitized configuration files for all services

---

## Project Context

This infrastructure was built as a comprehensive learning project to develop practical expertise in enterprise-grade systems architecture. The focus was on building a realistic, maintainable system that demonstrates understanding of networking, security, virtualization, and operational best practices.

The project prioritizes documentation quality, architectural clarity, and honest reflection on challenges encountered. All claims are supported by evidence (screenshots, configuration files, command outputs) captured from the live system.

---

## Contact

**Built by:** Darrius Johnson

- **Email:** jdarrius246@gmail.com.com
- **LinkedIn:** https://www.linkedin.com/in/darrius-j-661180ab/
- **GitHub:** https://github.com/DarriusJ6

---

*This project is licensed under the MIT License. Configuration examples and documentation are provided as-is for educational purposes.*
=======
# Primecloud
 099a1117debaecad306543519b6a0d5cf57155c0
