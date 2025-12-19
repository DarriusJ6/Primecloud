# PrimeCloud Build Timeline

## Overview

This document provides a chronological breakdown of the PrimeCloud infrastructure build, including time invested, major milestones, and key decisions made during each phase. The project was completed over approximately 8-10 weeks of part-time work, with periods of intensive effort followed by documentation and testing phases.

---

## Timeline Summary

| Phase | Phase Name | Duration | Cumulative Time |
|-------|-----------|----------|-----------------|
| 0 | Planning & Design | 1 week | 1 week |
| 1 | Hardware Setup & Proxmox Installation | 3 days | ~1.5 weeks |
| 2 | Network Infrastructure & VLAN Configuration | 1 week | ~2.5 weeks |
| 3 | OPNsense Firewall Deployment | 4 days | ~3 weeks |
| 4 | Reverse Proxy & TLS Setup | 2 days | ~3.5 weeks |
| 5 | Core Services Deployment | 1 week | ~4.5 weeks |
| 6 | Identity & Authentication | 3 days | ~5 weeks |
| 7 | Supporting Services | 1 week | ~6 weeks |
| 8 | Monitoring & Observability | 3 days | ~6.5 weeks |
| 9 | Testing & Validation | 1 week | ~7.5 weeks |
| 10 | Documentation & Portfolio Preparation | 2 weeks | ~9.5 weeks |

**Total Time Investment:** Approximately 200-240 hours over 8-10 weeks

---

## Phase 0: Planning & Design (1 week, ~15 hours)

### Objectives
- Define infrastructure requirements and scope
- Design network architecture with VLAN segmentation
- Select technology stack and hardware platform
- Create initial architecture diagrams
- Establish documentation standards

### Key Activities
- Researched hypervisor options (Proxmox vs. ESXi vs. XCP-ng)
- Designed 5-VLAN network architecture with security zones
- Identified required services (authentication, database, monitoring)
- Purchased Dell PowerEdge R630 server (used/refurbished)
- Set up local git repository for configuration management
- Created initial network diagram (revised multiple times later)

### Deliverables
- Network architecture design document
- VLAN IP addressing scheme
- Service placement strategy
- Hardware procurement checklist

### Decisions Made
- Chose Proxmox VE for hypervisor (community edition, strong documentation)
- Selected OPNsense over pfSense (better plugin ecosystem, cleaner UI)
- Decided on LXC containers over VMs for efficiency
- Committed to forward-authentication pattern using Authelia

---

## Phase 1: Hardware Setup & Proxmox Installation (3 days, ~20 hours)

### Objectives
- Install Proxmox VE on Dell R630
- Configure RAID storage
- Establish basic network connectivity
- Configure iDRAC remote management
- Verify hardware functionality

### Key Activities
- Configured RAID 10 using Dell PERC controller
- Installed Proxmox VE 8.x (later upgraded to 9.x)
- Set up initial network bridge (vmbr0) for WAN connectivity
- Configured iDRAC for out-of-band management
- Applied Proxmox updates and removed enterprise repository nag

### Deliverables
- Functional Proxmox host accessible via web UI
- RAID arrays healthy and initialized
- Baseline system snapshots

### Challenges
- BIOS RAID configuration learning curve
- Initial confusion about Proxmox networking (bridge vs. bond)
- Enterprise repository warnings (resolved by switching to no-subscription repo)

---

## Phase 2: Network Infrastructure & VLAN Configuration (1 week, ~30 hours)

### Objectives
- Implement VLAN segmentation
- Configure managed switch
- Establish internal network connectivity
- Create VLAN-aware bridge in Proxmox

### Key Activities
- **Week 1 Attempt:** Tried building without managed switch (failed)
- Purchased first "managed" switch (actually unmanaged, returned)
- Purchased second managed switch (VLAN 1 couldn't be removed, returned)
- Purchased TP-Link TL-SG108E (success)
- Configured 802.1Q VLANs on switch
- Set port 1/0/1 as trunk, other ports as access
- Created vmbr1 bridge in Proxmox with VLAN awareness
- Added vmbr1.10 sub-interface for management network participation

### Deliverables
- Functional VLAN segmentation
- Managed switch properly configured
- Proxmox host accessible on both WAN (vmbr0) and management network (vmbr1.10)
- Documented port assignments and VLAN mappings

### Challenges
- **Major issue:** Network equipment selection and multiple returns
- Connectivity troubleshooting consumed significant time
- Understanding VLAN tagging vs. untagged access ports
- Discovering need for vmbr1.10 interface (not documented clearly)

### Lessons
- Hardware selection matters enormously
- Test equipment before committing to build timeline
- Network architecture is the foundational layer—get it right first

---

## Phase 3: OPNsense Firewall Deployment (4 days, ~25 hours)

### Objectives
- Deploy OPNsense as VM
- Configure all VLAN interfaces
- Establish inter-VLAN routing
- Implement firewall rules
- Configure DNS resolver

### Key Activities
- Created VM 100 with multiple virtual NICs (WAN + internal VLANs)
- Configured OPNsense interface assignments for all VLANs
- Bridged LAN and VLAN 10 in interface assignments (critical discovery)
- Set up Unbound DNS resolver for internal name resolution
- Configured DHCP servers per VLAN (static reservations for all services)
- Implemented default-deny firewall policy with explicit allow rules
- Set up port forwarding for 80/443 to Traefik in DMZ

### Deliverables
- Functional OPNsense router with all VLANs operational
- Inter-VLAN routing working correctly
- Firewall rules documented in matrix format
- DNS resolution for .local domain

### Challenges
- Interface assignment confusion (needed to bridge LAN + VLAN 10)
- Firewall rule testing required multiple VMs to verify traffic flow
- DNS resolver configuration subtleties (forwarding vs. recursive)

---

## Phase 4: Reverse Proxy & TLS Setup (2 days, ~12 hours)

### Objectives
- Deploy Traefik in DMZ (VLAN 20)
- Configure automatic TLS via Let's Encrypt
- Establish dynamic routing configuration
- Integrate forward-authentication middleware

### Key Activities
- Created CT 110 (Traefik) on VLAN 20
- Configured Traefik static configuration (entrypoints, certificate resolvers)
- Set up Let's Encrypt HTTP-01 challenge (chose over DNS-01 for simplicity)
- Created dynamic configuration for routers and services
- Tested TLS certificate acquisition (successful on first try)
- Configured Traefik dashboard with authentication protection

### Deliverables
- Functional reverse proxy with automatic HTTPS
- Valid TLS certificates for primary domain
- Dynamic routing configuration structure established

### Challenges
- Initial routing configuration syntax errors (copy-paste mistakes)
- Understanding Traefik v3 configuration changes from v2 documentation
- Debugging route matching with debug logs

---

## Phase 5: Core Services Deployment (1 week, ~35 hours)

### Objectives
- Deploy PostgreSQL database
- Deploy Vaultwarden for secrets management
- Deploy Gitea for version control
- Establish backup repository with Restic

### Key Activities
- Created CT 310 (PostgreSQL) on VLAN 30
- Configured PostgreSQL with multiple databases (one per service)
- Created dedicated PostgreSQL users with restricted permissions
- Deployed Vaultwarden (CT 312) with PostgreSQL backend
- Configured Vaultwarden for internal access only
- Deployed Gitea (CT 313) with PostgreSQL integration
- Set up Restic repository (CT 350) for encrypted backups
- Configured automated backup scripts (PostgreSQL dumps)

### Deliverables
- Centralized database service operational
- Secrets management system functional
- Git repository hosting available
- Backup infrastructure established

### Challenges
- PostgreSQL connection string configuration across multiple services
- Unprivileged container issues with Docker (switched to privileged mode)
- Backup encryption key management (chicken-and-egg with Vaultwarden)

---

## Phase 6: Identity & Authentication (3 days, ~20 hours)

### Objectives
- Deploy Authelia as authentication gateway
- Configure forward-auth integration with Traefik
- Establish user database
- Implement session management

### Key Activities
- Created CT 311 (Authelia) on VLAN 30
- Configured Authelia with file-based user backend (LDAP-ready architecture)
- Integrated Authelia with Traefik via forward-auth middleware
- Configured session cookie settings and domain policies
- Created access control rules per service
- Tested authentication flow end-to-end

### Deliverables
- Centralized authentication gateway operational
- All backend services protected by authentication
- User access controls enforced

### Challenges
- **Major issue:** Login loop due to malformed configuration (copy-paste error)
- Session cookie domain configuration subtleties
- Understanding forward-auth request flow and header injection

### Lessons
- Always validate YAML configuration with linters
- Test authentication flow before deploying multiple services behind it

---

## Phase 7: Supporting Services (1 week, ~30 hours)

### Objectives
- Deploy monitoring infrastructure
- Deploy CI/CD pipeline
- Configure service integrations
- Establish operational tooling

### Key Activities
- Created CT 330 (Monitoring) with Prometheus + Grafana
- Configured Prometheus scrape targets for all services
- Built custom Grafana dashboards (infrastructure, applications, database)
- Deployed Woodpecker CI (CT 340) for automated builds
- Integrated Woodpecker with Gitea for repository webhooks
- Configured node exporters on all containers
- Set up PostgreSQL exporter for database metrics

### Deliverables
- Comprehensive monitoring stack operational
- Custom dashboards providing real-time visibility
- CI/CD pipeline functional and integrated with version control

### Challenges
- Prometheus service discovery configuration
- Grafana datasource authentication
- Woodpecker agent registration and pipeline syntax

---

## Phase 8: Monitoring & Observability (3 days, ~15 hours)

### Objectives
- Refine monitoring dashboards
- Configure alerting (preparation only)
- Establish baseline metrics
- Document operational procedures

### Key Activities
- Created infrastructure overview dashboard
- Built per-service detailed dashboards
- Configured Prometheus retention policy (30 days)
- Documented alerting rules (not yet connected to notification channels)
- Established baseline metrics for capacity planning
- Tested metrics accuracy and scrape interval tuning

### Deliverables
- Production-ready monitoring infrastructure
- Documented alert rules (ready for future notification integration)
- Baseline performance metrics captured

---

## Phase 9: Testing & Validation (1 week, ~25 hours)

### Objectives
- Validate all service functionality
- Test disaster recovery procedures
- Verify firewall rules
- Confirm backup/restore operations
- Stress test infrastructure

### Key Activities
- Performed end-to-end authentication flow testing
- Tested inter-VLAN connectivity with intentional rule violations
- Validated backup procedures (PostgreSQL dump + Restic encryption)
- Simulated container failure and restart
- Tested certificate renewal process
- Verified monitoring alert generation (simulated failures)
- Used VLAN 99 (Lab) for destructive testing

### Deliverables
- Validated operational infrastructure
- Confirmed disaster recovery procedures
- Identified performance bottlenecks (file transfer issues)

### Challenges
- Discovering file transfer performance degradation
- Validating backup restore without destroying production data
- Ensuring VLAN isolation was truly enforced

---

## Phase 10: Documentation & Portfolio Preparation (2 weeks, ~45 hours)

### Objectives
- Create comprehensive technical documentation
- Build architecture diagrams
- Capture screenshots and evidence
- Write portfolio-ready materials
- Sanitize configuration files for publication

### Key Activities
- Created network architecture diagram (Mermaid)
- Created service flow sequence diagram (Mermaid)
- Created security zones diagram (Mermaid)
- Captured screenshots of all service dashboards
- Exported configuration files and redacted secrets
- Wrote technical overview document
- Wrote lessons learned document
- Created this build timeline document
- Developed README for public portfolio
- Organized evidence folder with all artifacts

### Deliverables
- Complete documentation package
- Professional portfolio materials
- Sanitized configuration examples
- Architecture diagrams
- Evidence capture (screenshots, configs, logs)

### Lessons
- Documentation concurrent with build is significantly easier than retroactive documentation
- Screenshots and evidence capture should be systematic, not ad-hoc

---

## Post-Deployment Activities (Ongoing)

### Operational Maintenance
- Weekly backup validation
- Monthly security update application
- Quarterly capacity planning review
- Continuous monitoring and alert tuning

### Planned Future Enhancements
- LDAP integration for user management
- High availability with second Proxmox node
- Additional client applications in VLAN 40
- External notification integration for alerts
- Automated configuration management with Ansible

---

## Conclusion

The PrimeCloud build required approximately 200-240 hours of effort spread across 8-10 weeks. The largest time investments were in network infrastructure troubleshooting and documentation, with network issues alone consuming nearly 30 hours due to equipment selection mistakes.

The project successfully achieved its goals of building production-grade infrastructure with proper security segmentation, centralized authentication, comprehensive monitoring, and complete documentation. Time invested in documentation and evidence capture proved worthwhile for portfolio presentation and operational clarity.

Future infrastructure projects will benefit significantly from lessons learned, particularly in upfront planning and equipment validation.Claude is AI and can make mistakes. Please double-check responses.
