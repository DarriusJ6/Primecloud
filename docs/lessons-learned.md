# Lessons Learned: PrimeCloud Build

## Overview

Building PrimeCloud from bare metal through to operational services involved numerous challenges, mistakes, and learning opportunities. This document captures the most significant lessons encountered during the project, organized by category. The goal is honest reflection on what went wrong, what went right, and what would be done differently on a future build.

---

## Network Infrastructure: The Hardest Part

### Challenge: Physical Network Configuration

The single biggest obstacle during the entire build was establishing reliable network connectivity between the physical server, the managed switch, and the various VLANs. This consumed more time than any other aspect of the project, primarily due to equipment selection mistakes and a lack of upfront understanding of VLAN requirements.

**Mistake 1: Starting Without a Managed Switch**  
Initially attempted to build the segmented network without a managed switch, relying entirely on Proxmox and OPNsense for VLAN tagging. This led to significant connectivity issues, particularly when trying to access web interfaces for services on internal VLANs. Traffic would route correctly in some directions but fail in others, creating unpredictable behavior that was difficult to troubleshoot.

**Mistake 2: Wrong Switch Selection (Twice)**  
Purchased the first "managed" switch without verifying VLAN capability. It turned out to be unmanaged, making it completely unsuitable for a segmented network.

The second switch advertised VLAN support but had a critical limitation: VLAN 1 (the default/system VLAN) could not be removed from trunk ports. This meant all VLANs effectively leaked onto VLAN 1, completely breaking the intended network segmentation. Spent several days troubleshooting before realizing this was a hardware limitation, not a configuration error.

The third switch (TP-Link TL-SG108E) finally worked as expected, supporting proper 802.1Q VLAN tagging with full control over port assignments.

**What Fixed It: vmbr1.10 Interface**  
Even with a proper managed switch, connectivity issues persisted until adding a VLAN sub-interface on vmbr1 for VLAN 10. Proxmox needed vmbr1.10 configured with IP address 10.10.10.3/24 to properly participate in management traffic. This wasn't immediately obvious from documentation and required significant trial and error to discover.

Additionally, bridging the LAN and VLAN 10 interfaces in OPNsense's interface assignments was necessary for proper routing. Without this bridge, the gateway couldn't correctly forward traffic between the WAN and management network.

**What I'd Do Differently:**  
Research network equipment requirements before purchasing anything. Verify exact VLAN capabilities, understand the difference between managed/smart/unmanaged switches, and test equipment return policies before committing to a build timeline. Plan the network architecture on paper first, with explicit interface assignments documented before touching hardware.

---

## File Transfer Performance Issues

### Challenge: Network Slowdown During File Transfers

Transferring files from the workstation to the Proxmox environment caused dramatic network speed degradation, affecting not just the file transfer but all network traffic. This made iterative configuration testing frustrating, as copying updated config files or uploading container templates would temporarily disrupt service access.

**Root Cause (Suspected):**  
Likely related to a combination of factors:
- vmbr0 sharing bandwidth with administrative traffic and file transfers
- Lack of QoS configuration on the network
- Insufficient MTU optimization for large file transfers
- Potential duplex mismatch or auto-negotiation issues on physical NICs

**Workaround:**  
Scheduled large file transfers during off-hours and used compression (gzip before transfer) to reduce transfer times. For frequent small config changes, used git repositories cloned on the Proxmox host rather than direct SCP transfers.

**What I'd Do Differently:**  
Implement proper network segmentation earlier, with dedicated NICs for management traffic versus data traffic. Configure QoS rules in OPNsense to prevent bulk transfers from saturating the network. Test network performance with iperf before beginning service deployment.

---

## Container and Privilege Management

### Challenge: Unprivileged Containers and Docker AppArmor Conflicts

Attempted to follow security best practices by using unprivileged LXC containers for all services. This immediately caused issues with services expecting to bind to privileged ports (<1024) or requiring specific kernel capabilities.

Docker containers running inside LXC containers hit AppArmor policy violations, causing services to fail silently or produce cryptic permission errors. Troubleshooting required enabling verbose logging, which revealed that AppArmor was blocking perfectly legitimate operations.

**Resolution:**  
Migrated most containers to privileged mode after confirming that the VLAN isolation provided sufficient security for a single-operator environment. For services requiring Docker, disabled AppArmor profiles or configured custom policies to allow necessary operations.

**Lesson:**  
Unprivileged containers are ideal for multi-tenant environments but add significant complexity for a home lab. The security benefit was outweighed by operational overhead in this context. Future builds would default to privileged containers with network isolation, reserving unprivileged containers only for truly untrusted workloads.

---

## Authentication and Application Integration

### Challenge: Authelia Login Loop

Spent several hours debugging an authentication loop where Authelia would accept credentials but immediately redirect back to the login page without creating a session. Users could never successfully authenticate, despite correct username/password combinations.

**Root Cause:**  
Human error: incorrectly pasted configuration block in authelia-config.yml. Specifically, the session domain and cookie settings were malformed, causing the session cookie to fail validation on subsequent requests.

**Resolution:**  
Used a YAML linter (yamllint) to validate the configuration file, which immediately identified the syntax error. Corrected the indentation and whitespace issues, restarted Authelia, and authentication worked immediately.

**Lesson:**  
Never paste multi-line configuration blocks without validating syntax. Use configuration management tools (Ansible, Terraform) or at minimum run linters before deploying configuration changes. Set up pre-deployment validation scripts that check syntax, required fields, and type constraints before restarting services.

---

## Traefik Routing Configuration

### Challenge: Traefik Routes Not Matching

Services were unreachable despite correct DNS configuration and proper firewall rules. Traefik logs showed requests arriving but no routes matching, resulting in 404 responses.

**Root Cause:**  
Human error: typo in dynamic configuration file. Specifically, router rule syntax was incorrect (wrong host header comparison operator) due to copy-paste error from documentation examples that weren't adapted to the actual deployment.

**Resolution:**  
Enabled Traefik's debug logging to see exact rule matching behavior. Discovered the syntax error, corrected the dynamic configuration, and Traefik immediately began routing traffic correctly.

**Lesson:**  
Most issues were self-inflicted through careless copy-paste. This highlights the importance of:
1. Understanding configuration syntax before copying examples
2. Using version-controlled configuration files with commit messages
3. Testing changes in the lab VLAN before deploying to production services
4. Building a library of tested configuration snippets rather than repeatedly searching documentation

---

## What Worked Well

### Version Control from Day One

Initializing a git repository at the project start and committing configuration changes incrementally proved invaluable. Being able to roll back changes, review configuration history, and track decision rationale through commit messages saved significant time during troubleshooting.

### Documentation During Build

Taking screenshots, capturing command outputs, and writing documentation concurrently with infrastructure deployment meant documentation stayed accurate and complete. Attempting to recreate documentation after the build would have resulted in forgotten steps and missing context.

### Iterative Testing in VLAN 99 (Lab)

Having a dedicated isolated VLAN for testing new configurations prevented several near-disasters from affecting production services. Being able to deploy experimental changes, observe failures, and correct course without impacting operational services was essential for learning.

### Container-Based Architecture

Using LXC containers for services (rather than VMs) significantly reduced resource overhead and provisioning time. This made experimentation less costly and enabled running more services on a single physical host than would be practical with full virtualization.

---

## Future Improvements

### What I'd Change on a Rebuild

**1. Plan Network Infrastructure First**  
Complete all network design, equipment selection, and physical cabling before installing Proxmox. Validate switch VLAN configuration before connecting the server. Test network segmentation with a simple VM/container before deploying complex services.

**2. Implement Configuration Management Earlier**  
Use Ansible playbooks or similar tooling from the beginning instead of manual configuration. This would prevent copy-paste errors, ensure reproducibility, and serve as implicit documentation.

**3. Set Up CI/CD for Infrastructure Changes**  
Create a pipeline that validates configuration syntax, runs linting tools, and performs dry-run deployments before applying changes to production services.

**4. Deploy Monitoring Before Services**  
Have Prometheus and Grafana operational before deploying application services. This would provide visibility during initial deployment and make troubleshooting significantly easier.

**5. Standardize Container Templates**  
Create pre-configured LXC templates with common tools (git, vim, curl, systemd configs) to speed up deployment and ensure consistency across containers.

**6. Document Network Topology with Real IPs Earlier**  
Maintain a living document showing current IP assignments, VLAN configurations, and firewall rules. This would reduce time spent checking configurations and prevent IP conflicts.

---

## Key Takeaways

1. **Hardware limitations are real**: Network equipment capabilities matter more than expected. Don't cheap out on switches when building production-style infrastructure.

2. **Human error dominates**: The majority of issues were self-inflicted through careless configuration changes, not fundamental architectural problems. Better tooling (linters, validators, dry-run testing) would prevent most issues.

3. **Network architecture is foundational**: Get networking right first. Everything else depends on it. Attempting to retrofit proper network segmentation after deploying services is exponentially harder than building it correctly initially.

4. **Documentation is infrastructure**: Treating documentation as a first-class deliverable (not an afterthought) creates immense value for troubleshooting, knowledge transfer, and portfolio presentation.

5. **Learning requires failure**: The issues encountered taught more than smooth deployments would have. Troubleshooting forced deep understanding of protocol behavior, configuration relationships, and system interactions.

6. **Security and convenience trade off**: Every security control adds complexity. Finding the right balance requires understanding threat models realistically (home lab vs. multi-tenant production).

---

## Conclusion

PrimeCloud was built through iteration, failure, and eventual success. The challenges encountered—particularly in networking—provided practical education that theoretical study couldn't replicate. Future infrastructure projects will benefit significantly from lessons learned here, particularly around planning, validation, and avoiding premature complexity.

The project accomplished its goal: demonstrating ability to design, build, troubleshoot, and document enterprise-style infrastructure. The mistakes made along the way are as valuable as the successes, if not more so.
