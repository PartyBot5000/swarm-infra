# Swarm Infrastructure

Highly Available, Automated Home Lab Cluster — 7-node Docker Swarm with distributed GlusterFS storage and automated failover via Keepalived VIP.

## Architecture

| Layer | Component | Nodes |
|-------|-----------|-------|
| Control Plane | Docker Swarm Managers | node1, node2, node3 |
| Data Plane | Docker Swarm Workers | node4–node7 |
| Storage | GlusterFS 1×3 Replicated Volume | node1, node2, node3 |
| HA Networking | Keepalived VIP (192.168.1.100) | node1, node2, node3 |

## Quick Start

```bash
# Run the full provisioning pipeline
./provision-cluster.sh
```

## Phases

1. **Bootstrap** — Distribute SSH keys to all nodes
2. **Ansible** — Install Docker, initialise Swarm, provision GlusterFS
3. **Setup** — Apply labels, create volumes, generate Docker Secrets
4. **Deploy** — Deploy all service stacks

## Service Stacks

| Stack | Services | Notes |
|-------|----------|-------|
| `ha/` | Keepalived | VIP failover for host-mode services |
| `management/` | Portainer CE | Cluster observability |
| `monitoring/` | InfluxDB, Grafana, Telegraf | Metrics and dashboards |
| `network/` | Pi-hole, WireGuard, UniFi Controller | DNS, VPN, network management |

## Requirements

- 7 nodes running Ubuntu 24.04 LTS (4 GB RAM, 32 GB storage)
- Static IPs: 192.168.1.11 – 192.168.1.17
- SSH key-based auth from node1 to all nodes

## Configuration

All configuration is stored in this repository — the single source of truth.
Populate placeholder secrets in `secrets/*.txt` before running.
