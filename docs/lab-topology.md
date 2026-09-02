# Lab Topology

| Host | OS | IP | Role |
|---|---|---:|---|
| sre-control01 | Ubuntu 24.04 | 192.168.56.10 | Ansible control |
| repo01 | Ubuntu 24.04 | 192.168.56.20 | APT/RPM repository |
| ubu-canary01 | Ubuntu 24.04 | 192.168.56.31 | Canary |
| ubu-prod01 | Ubuntu 24.04 | 192.168.56.32 | Production |
| rocky-canary01 | Rocky Linux 9 | 192.168.56.41 | Canary |
| rocky-prod01 | Rocky Linux 9 | 192.168.56.42 | Production |

Each VM should normally have:

- Adapter 1: NAT
- Adapter 2: VirtualBox Host-Only Network (`192.168.56.0/24`)
