# Swarm Infrastructure

Highly Available, Automated Home Lab Cluster — 7-node Docker Swarm with distributed GlusterFS storage and automated failover via Keepalived VIP.

## Architecture

- **Control Plane:** 3 Manager Nodes (node1, node2, node3) — Raft consensus
- **Data Plane:** 4 Worker Nodes (node4–node7)
- **Storage:** GlusterFS 1×3 Replicated Volume on managers (3-way mirror — survives 2 simultaneous node failures)
- **HA Networking:** Keepalived VIP (192.168.1.100) floats across managers for host-mode services (Pi-hole, WireGuard)

## How to Deploy

This repo is designed to be deployed entirely from the control machine. You only need to provide the node details:

1. **Install the OS** on each of the 7 nodes (Ubuntu 24.04 LTS, 4 GB RAM, 32 GB storage)
2. **Connect them to the network** with static IPs (e.g., 192.168.1.11–117)
3. **Give me the hostnames and SSH credentials** for each node
4. I populate `ansible/inventory`, fill the secrets, and run `./provision-cluster.sh`

The provisioning pipeline runs 4 phases automatically:

```
Phase 1: Bootstrap  — Distribute SSH keys from control machine to all nodes
Phase 2: Ansible    — Install Docker, initialise Swarm, provision GlusterFS
Phase 3: Setup      — Apply HA labels, create Docker volumes, generate secrets
Phase 4: Deploy     — Deploy all service stacks via docker stack deploy
```

## Service Stacks

| Stack | Services | Network | HA |
|-------|----------|---------|----|
| `ha/` | Keepalived | host | global on managers |
| `management/` | Portainer CE | overlay | manager-only |
| `monitoring/` | InfluxDB 2.7, Grafana, Telegraf | overlay | Telegraf: global |
| `network/` | Pi-hole, WireGuard, UniFi Controller | host + overlay | Pi-hole/WG: HA-constrained |

## Configuration

All configuration lives in this repository — single source of truth.

- `ansible/inventory` — node hostnames and SSH credentials (populated at deploy time)
- `secrets/*.txt` — plaintext secret values (consumed to create Docker Secrets)
- `stacks/*/docker-compose.yml` — service definitions
- `stacks/monitoring/grafana/provisioning/` — Grafana datasources and dashboards
- `stacks/monitoring/telegraf/telegraf.conf` — Telegraf metrics collector config

## Repository Structure

```
swarm-infra/
├── .gitignore
├── README.md
├── provision-cluster.sh          # Master orchestration — runs all 4 phases
├── ansible/
│   ├── inventory                 # ← POPULATED at deploy time (gitignored)
│   ├── inventory.template        # Reference template
│   ├── install_docker.yml
│   ├── init_swarm.yml
│   └── provision_gluster.yml
├── bootstrap/
│   ├── authorized_keys.pub       # Generated during bootstrap
│   └── bootstrap-node.sh         # SSH key distribution via sshpass
├── scripts/
│   ├── deploy.sh                 # Phase 4 — stack deployment
│   └── setup.sh                  # Phase 3 — labels, volumes, secrets
├── secrets/
│   ├── grafana_admin_password.txt
│   ├── influxdb_user_password.txt
│   └── pihole_webpw.txt
└── stacks/
    ├── ha/
    │   └── docker-compose.yml
    ├── management/
    │   └── docker-compose.yml
    ├── monitoring/
    │   ├── docker-compose.yml
    │   ├── grafana/
    │   │   └── provisioning/
    │   │       ├── dashboards/
    │   │       │   ├── dashboard-nodes-placeholder.json
    │   │       │   └── providers.yml
    │   │       └── datasources/
    │   │           └── datasources.yml
    │   └── telegraf/
    │       └── telegraf.conf
    └── network/
        └── docker-compose.yml
```

## Notes

- All credentials injected via Docker Secrets — no plaintext passwords in compose files
- All stateful volumes declared as `external: true` — GlusterFS path abstracted in `setup.sh`
- Manual GUI changes via Portainer are strictly for debugging only
- Ansible runs inside a Docker container — no Ansible installation needed on the control machine
