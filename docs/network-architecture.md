| VLAN ID | Name | Subnet | Gateway | Purpose |
|---------|------|--------|---------|---------|
| 10 | MGMT | 10.10.10.0/24 | 10.10.10.254 | Management network |
| 20 | DMZ | 10.10.20.0/24 | 10.10.20.254 | Reverse proxy, public-facing |
| 30 | SERVICES | 10.10.30.0/24 | 10.10.30.254 | Core backend services |
| 40 | APPS | 10.10.40.0/24 | 10.10.40.254 | Client applications |
| 99 | LAB | 10.10.99.0/24 | 10.10.99.254 | Testing/experimental |
