# Swarm Infrastructure

Highly Available, Automated Home Lab Cluster — 7-node Docker Swarm with distributed GlusterFS storage and automated failover via Keepalived VIP.

**Hardware:** [Sipeed NanoCluster](https://wiki.sipeed.com/hardware/en/cluster/NanoCluster/index.html) — 7× Longan Module 3H (LM3H) on JL6108 Gigabit switch baseboard.

📖 **[Full Hardware Knowledge Base](docs/SIPEED-NANOCLUSTER-KB.md)** — specs, flashing, networking, thermal management, deployment checklist, and troubleshooting.

## Architecture

- **Control Plane:** 3 Manager Nodes (node1, node2, node3) — Raft consensus
- **Data Plane:** 4 Worker Nodes (node4–node7)
- **Storage:** GlusterFS 1×3 Replicated Volume on managers (3-way mirror — survives 2 simultaneous node failures)
- **HA Networking:** Keepalived VIP (192.168.1.100) floats across managers for host-mode services (Pi-hole, WireGuard)
- **Network:** 100M Ethernet per LM3H module via JL6108 internal switch (switch IP: `10.10.11.10`)

## How to Deploy

This repo is designed to be deployed entirely from the control machine. You only need to provide the node details:

1. **Flash the OS** on each of the 7 LM3H modules — [Official Debian CLI image](https://wiki.sipeed.com/hardware/en/longan/h618/lpi3h/3_images.html) (v20240106+ for eMMC boot). Default credentials: `sipeed` / `licheepi` or `root` / `root`
2. **Connect them to the network** — all modules share the JL6108 internal switch. Assign static IPs (e.g., 192.168.1.11–17). mDNS discovery available: `ssh sipeed@lpi3h.local`
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

**Populated at deploy time (gitignored):**

| File | Purpose | Source |
|------|---------|--------|
| `ansible/inventory` | Node hostnames, IPs, SSH usernames, SSH passwords | Provided by user before deployment |
| `secrets/grafana_admin_password.txt` | Grafana admin password | Provided by user before deployment |
| `secrets/influxdb_user_password.txt` | InfluxDB admin password | Provided by user before deployment |
| `secrets/pihole_webpw.txt` | Pi-hole web interface password | Provided by user before deployment |

**Committed to repo:**

| File | Purpose |
|------|---------|
| `ansible/inventory.template` | Reference template for inventory format |
| `secrets/*.txt.example` | Placeholder values — copy to `.txt` and edit |
| `stacks/*/docker-compose.yml` | Service definitions |
| `stacks/monitoring/grafana/provisioning/` | Grafana datasources and dashboards |
| `stacks/monitoring/telegraf/telegraf.conf` | Telegraf metrics collector config |

## Repository Structure

**Legend:** `🔒` = gitignored (populated at deploy time)

```
swarm-infra/
├── .gitignore
├── README.md
├── provision-cluster.sh          # Master orchestration — runs all 4 phases
├── ansible/
│   ├── inventory                 # 🔒 POPULATED at deploy time (node credentials)
│   ├── inventory.template        # Reference template (committed)
│   ├── install_docker.yml
│   ├── init_swarm.yml
│   └── provision_gluster.yml
├── bootstrap/
│   ├── authorized_keys.pub       # Generated during bootstrap from control machine key
│   └── bootstrap-node.sh         # SSH key distribution via sshpass
├── scripts/
│   ├── deploy.sh                 # Phase 4 — stack deployment
│   └── setup.sh                  # Phase 3 — labels, volumes, secrets
├── secrets/
│   ├── grafana_admin_password.txt     # 🔒 POPULATED at deploy time
│   ├── grafana_admin_password.txt.example
│   ├── influxdb_user_password.txt     # 🔒 POPULATED at deploy time
│   ├── influxdb_user_password.txt.example
│   ├── pihole_webpw.txt               # 🔒 POPULATED at deploy time
│   └── pihole_webpw.txt.example
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

## Hardware-Specific Notes (Sipeed NanoCluster)

See the full knowledge base: [docs/SIPEED-NANOCLUSTER-KB.md](docs/SIPEED-NANOCLUSTER-KB.md)

| Consideration | Detail |
|---------------|--------|
| **Ethernet** | LM3H modules have 100M Ethernet (not Gigabit). Inter-node traffic limited to ~10 MB/s |
| **Thermal** | Vendor Debian image required — Armbian/mainline triggers false thermal shutdowns |
| **Power** | Cluster draws max ~30W at peak — well within 60W PD limit |
| **Storage** | 32GB eMMC per module. ~22GB usable per GlusterFS brick after OS + Docker overhead |
| **Switch** | JL6108 web UI at `10.10.11.10` (admin/admin). Linux compatibility issues — use Windows |
| **mDNS** | All modules discoverable as `lpi3h.local` (may have suffixes) |
| **OS Image** | Official Debian CLI (v20240407+) — root SSH enabled, GPIO sysfs included |
