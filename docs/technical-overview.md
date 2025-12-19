# PrimeCloud Technical Overview

## System Architecture

PrimeCloud is built on a single Dell PowerEdge R630 server running Proxmox VE 9.0.10 as the Type-1 hypervisor. The infrastructure uses a combination of virtual machines and LXC containers, with one VM (OPNsense) and eight LXC containers hosting all services. This approach balances isolation requirements with resource efficiency.

The physical server connects to a TP-Link managed switch via two network interfaces: eno3 provides WAN connectivity (bridged as vmbr0), while eno4 handles internal traffic (bridged as vmbr1 with VLAN awareness enabled). The managed switch configuration enforces VLAN segmentation at the physical layer, with port 1/0/1 configured as a trunk carrying all internal VLANs.

Proxmox itself maintains dual connectivity: vmbr0 for administrative access via the existing network (192.168.1.203/24) and vmbr1.10 for management plane traffic within the isolated infrastructure (10.10.10.3/24). This separation ensures that infrastructure management remains accessible even if internal routing fails.

---

## Network Design and VLAN Strategy

The network architecture implements five distinct VLANs, each serving a specific security and operational purpose:

**VLAN 10 (Management)** - 10.10.10.0/24  
Houses infrastructure management interfaces: Proxmox web UI, iDRAC, and OPNsense administrative access. This network is the most restricted, with firewall rules permitting only SSH and HTTPS from specific administrative workstations. The gateway (10.10.10.254) is provided by OPNsense.

**VLAN 20 (DMZ)** - 10.10.20.0/24  
Hosts the Traefik reverse proxy (10.10.20.10), which serves as the entry point for all external traffic. This network is intentionally isolated from backend services except through explicitly permitted firewall rules. The DMZ design prevents compromised edge services from directly accessing internal resources.

**VLAN 30 (Services)** - 10.10.30.0/24  
Contains all backend services: PostgreSQL (10.10.30.10), Authelia (10.10.30.11), Vaultwarden (10.10.30.12), Gitea (10.10.30.13), monitoring stack (10.10.30.30), Woodpecker CI (10.10.30.40), and Restic backup repository (10.10.30.50). Services in this VLAN cannot initiate outbound internet connections, enforcing an internal-only security posture.

**VLAN 40 (Apps)** - 10.10.40.0/24  
Reserved for future client applications. Currently unpopulated but pre-configured with firewall rules allowing communication with VLAN 30 services only. This separation enables hosting untrusted or customer-specific workloads without compromising core infrastructure.

**VLAN 99 (Lab)** - 10.10.99.0/24  
Isolated testing environment with no production access. Used for experimenting with new services, testing configuration changes, and validating updates before deploying to production VLANs.

All inter-VLAN routing is handled by OPNsense, which acts as the default gateway for each segment. The firewall enforces default-deny rules with explicit allow policies for required traffic flows.

---

## VM and Container Placement Rationale

**OPNsense (VM 100)** is deployed as a full virtual machine rather than a container due to its kernel-level networking requirements and the need for direct hardware access to multiple network interfaces. The VM has virtual NICs connected to both vmbr0 (WAN) and vmbr1 (internal), with VLAN sub-interfaces created for each internal network segment.

**All other services use LXC containers** for resource efficiency and faster provisioning. LXC provides sufficient isolation for trusted services while consuming less overhead than full VMs. Each container is assigned to a specific VLAN via the vmbr1 bridge with VLAN tagging.

**Traefik (CT 110)** is placed in the DMZ (VLAN 20) as the sole publicly accessible service. Its position at the network edge allows it to terminate TLS connections and perform initial request routing before traffic reaches internal networks.

**PostgreSQL (CT 310)** runs in a dedicated container on VLAN 30 to provide centralized data storage for multiple services. While this creates a single point of failure, it simplifies backup procedures, connection management, and database administration. Each application uses a separate database schema within the same PostgreSQL instance, providing logical separation without the overhead of multiple database servers.

**Authentication services (Authelia CT 311)** reside on VLAN 30 rather than the DMZ to prevent direct internet exposure. Traefik forwards authentication requests to Authelia using its forward-auth middleware, and only authenticated requests proceed to backend applications.

**Supporting services** (Vaultwarden, Gitea, Monitoring, Woodpecker, Restic) all reside on VLAN 30 as they serve internal operational needs and do not require direct external access.

---

## Identity and Authentication Flow

PrimeCloud implements a forward-authentication architecture using Authelia as the authentication gateway. The flow proceeds as follows:

1. User initiates HTTPS request to a protected service (e.g., https://app.primecloud.io)
2. Traefik receives the request on port 443, terminates TLS, and checks for an authentication middleware attachment
3. Traefik forwards the request to Authelia's /api/verify endpoint to validate the user's session
4. If no valid session exists, Authelia returns a 302 redirect to the login page
5. User authenticates with Authelia (username/password, with optional 2FA)
6. Authelia creates a session cookie and redirects the user back to the original application
7. Traefik re-validates the session with Authelia, which now returns 200 OK with user identity headers
8. Traefik forwards the request to the backend application with injected headers (Remote-User, Remote-Email, etc.)

This design centralizes authentication logic in a single service while keeping application code simple. Applications trust the headers injected by Traefik after successful authentication, eliminating the need for each service to implement its own authentication system.

Authelia stores session data and user credentials in its own database within PostgreSQL. The system is configured to use file-based user storage initially but can be migrated to LDAP or Active Directory integration without application changes.

---

## Traffic Routing and TLS Termination

All external traffic enters through OPNsense on vmbr0 (WAN interface). The firewall is configured with port forwarding rules directing ports 80 and 443 to Traefik's container IP (10.10.20.10) on VLAN 20.

Traefik handles TLS certificate acquisition via Let's Encrypt using the HTTP-01 challenge method. Certificates are stored in acme.json (never committed to version control) and automatically renewed 30 days before expiration. HTTP-01 was chosen over DNS-01 to avoid storing DNS provider API credentials in the infrastructure.

Traefik's dynamic configuration defines routes based on Host headers, directing traffic to appropriate backend services. Each route can attach middleware chains for authentication, rate limiting, and header manipulation. Internal traffic from Traefik to backend services uses unencrypted HTTP since all traffic remains within the isolated VLAN 30 network.

The reverse proxy architecture provides several benefits:
- Single TLS termination point simplifies certificate management
- Centralized request logging and metrics collection
- Ability to add/remove backend services without exposing additional ports
- Protection of backend services from direct internet exposure

---

## Database Architecture and Separation

PostgreSQL 16 runs in a single LXC container (CT 310) and hosts multiple databases, each corresponding to a different service:

- `authelia` - Session storage and user credentials for Authelia
- `gitea` - Repository metadata and user data for Gitea
- `woodpecker` - CI/CD pipeline state and build history
- Additional databases created as new services are deployed

This centralized approach simplifies backup procedures (single pg_dump schedule), connection pooling, and resource management. Each service connects with a dedicated PostgreSQL user that has access only to its own database, providing logical separation at the permission level.

Connection strings are stored in each container's environment configuration (docker-compose.yml files or systemd units), with credentials managed through Vaultwarden for easy rotation.

The database container uses persistent storage mounted from Proxmox's local-lvm storage pool, ensuring data survives container restarts. Daily backups are performed using pg_dump and stored in the Restic repository on CT 350.

---

## Monitoring and Observability Design

The monitoring stack consists of Prometheus and Grafana running in CT 330 (VLAN 30). Prometheus scrapes metrics from multiple targets:

- **Node Exporter** on each LXC container (system-level metrics: CPU, memory, disk, network)
- **Traefik metrics endpoint** (request rates, latencies, response codes)
- **PostgreSQL Exporter** (connection counts, query performance, database size)
- **Proxmox exporter** (VM/CT resource usage, storage pool status)

Grafana provides visualization through custom dashboards covering:
- Infrastructure overview (all containers, resource utilization)
- Network traffic patterns (per-VLAN bandwidth, firewall rule hits)
- Application performance (request latency, error rates, database query times)
- Capacity planning (storage growth trends, memory pressure)

Prometheus is configured with a 30-day retention period, balancing historical data availability with storage constraints. Alerting rules are defined but not yet connected to external notification channels (future enhancement).

The monitoring infrastructure itself resides on VLAN 30, using read-only access patterns to scrape metrics without impacting production services.

---

## Backup, Isolation, and Fault Considerations

**Backup Strategy:**  
Restic repository (CT 350) provides encrypted, deduplicated backup storage. Daily automated backups include:
- PostgreSQL dumps from all databases
- Gitea repository data
- Vaultwarden vault database
- Critical configuration files from all containers

Backups are encrypted with a key stored in Vaultwarden, creating a dependency that requires careful bootstrap procedures during disaster recovery.

**Isolation:**  
VLAN segmentation enforces network-level isolation, with OPNsense firewall rules preventing unexpected traffic flows. LXC containers provide process-level isolation, though they share the host kernel (unlike full VMs). This is acceptable for trusted services within a single-operator environment.

**Single Points of Failure:**  
The infrastructure has several acknowledged SPOFs:
- Physical host (R630 server)
- OPNsense VM (routing and firewalling)
- PostgreSQL container (database services)
- Traefik container (external access)

These are accepted trade-offs for a single-node deployment. Future expansion toward high availability would require:
- Second Proxmox node in a cluster
- Floating IPs for critical services
- PostgreSQL replication
- Shared storage (Ceph or NFS)

**Fault Tolerance:**  
Container restart policies are configured as "unless-stopped," allowing automatic recovery from transient failures. Proxmox provides snapshot capabilities for rapid rollback if container configuration changes cause issues.

---

## Security Controls and Trust Boundaries

**Trust Boundary 1: Internet → DMZ**  
OPNsense firewall with stateful packet inspection filters inbound traffic, allowing only ports 80/443 to reach Traefik. IDS/IPS capabilities are available but not currently enabled (performance considerations).

**Trust Boundary 2: DMZ → Services**  
Traefik can only communicate with VLAN 30 services after OPNsense explicitly permits the traffic. Direct DMZ-to-database connections are blocked; all traffic must pass through application containers that enforce business logic.

**Trust Boundary 3: Services → Management**  
VLAN 30 services cannot access VLAN 10 management interfaces. Administrative access requires connection from specific workstations with known IP addresses.

**Defense in Depth:**  
- Network segmentation (VLANs + firewall)
- Application-level authentication (Authelia)
- Encryption in transit (TLS at edge)
- Encrypted backups (Restic)
- Secrets isolation (Vaultwarden)
- Minimal service exposure (only Traefik internet-facing)

**Accepted Risks:**  
- No intrusion detection/prevention actively running
- Single-factor authentication for most services (2FA available but not enforced)
- Internal traffic not encrypted (VLAN 30 uses HTTP)
- No runtime container security scanning

These risks are documented and represent conscious trade-offs between security, complexity, and operational overhead for a single-operator lab environment.

---

## Conclusion

PrimeCloud demonstrates a security-conscious approach to private cloud infrastructure, with clear separation of concerns, documented architectural decisions, and realistic acknowledgment of limitations. The design prioritizes maintainability and learning value over premature optimization or unnecessary complexity.
