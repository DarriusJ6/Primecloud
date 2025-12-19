# PrimeCloud VM & Container Inventory
**Note:** The `applications` database is provisioned but schema initialization has not yet occurred. This reflects a staged deployment approach where database resources are created ahead of application bootstrap.

This document lists all virtual machines and containers running in the
PrimeCloud private cloud environment.

| VM ID | Name | Type | VLAN | CPU | RAM | Disk | Purpose |
|------:|------|------|------|----:|-----:|------:|---------|
| 100 | OPNsense | VM | MGMT / All | 4 | 4GB | 32GB | Firewall / Router |
| 110 |REVERSE-PROXY | CT | DMZ | 2 | 2GB | 16GB | Reverse Proxy |
| 310 | POSTGRES | CT | SERVICES | 4 | 8GB | 200GB | Database |
| 311 | AUTHELIA | CT | SERVICES | 2 | 2GB | 10GB | Authentication |
| 312 | VAULT | CT | SERVICES | 2 | 2GB | 20GB | Secrets |
| 313 | GITEA | CT | SERVICES | 2 | 3GB | 50GB | GIT |
| 330 | MONITORING | CT | SERVICES | 4 | 8GB | 100GB | Logging/Monitoring |
| 340 | WOODPECKER | CT | SERVICES | 2 | 2GB | 20GB | Automation |
| 350 | RESTIC-REPO | CT | SERVICES | 2 | 1GB | 200GB | Backups |
