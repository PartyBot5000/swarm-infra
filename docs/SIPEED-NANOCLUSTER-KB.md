# Sipeed NanoCluster Knowledge Base

> **Hardware:** 7x Longan Module 3H (LM3H) on Sipeed NanoCluster baseboard.
> **Purpose:** Reference guide for provisioning, deployment, and troubleshooting the Docker Swarm cluster on this specific hardware.
> **Sources:** [Sipeed Wiki](https://wiki.sipeed.com/hardware/en/cluster/NanoCluster/index.html), [LM3H Hardware Docs](https://dl.sipeed.com/shareURL/LONGAN/LonganPi3H), [Armbian Forum](https://forum.armbian.com/topic/33449-sipeed-longanpi-3h/), [LM3H SDK](https://github.com/sipeed/LonganPi-3H-SDK).

---

## 1. Hardware Specifications

### Longan Module 3H (LM3H)

| Spec | Value |
|------|-------|
| SoC | Allwinner H618 |
| CPU | 4x ARM Cortex-A53 @ 1.5 GHz (shared 1MB L2 cache) |
| GPU | Arm Mali-G31 (OpenGL ES 3.2, Vulkan 1.1, OpenCL 2.0) |
| RAM | 2GB or 4GB 64-bit LPDDR4 |
| Storage | 32GB eMMC (on-board) + TF (microSD) slot |
| Ethernet | 100M (not Gigabit — see Networking section) |
| Wi-Fi | Wi-Fi 6 (802.11ax) |
| Bluetooth | Yes (BT 5.0) |
| USB | 2x USB-A Host, 1x USB-C OTG (Slot 1 only) |
| HDMI | 4K output (Slot 1 only, via baseboard passthrough) |
| GPIO | UART, I2C, SPI headers exposed per-module |
| Form Factor | Raspberry Pi Zero-style M.2 M-Key module |

### NanoCluster Baseboard

| Spec | Value |
|------|-------|
| SOM Slots | 7x dual M.2 M-Key vertical slots |
| Internal Switch | JL6108 RISC-V Gigabit Switch |
| Power | USB-C PD (max 60W) or optional 60W PoE |
| Base Power Draw | 3.6W (board alone) |
| Cooling | 60mm 2-pin fan (airflow toward Ethernet port) |
| Dimensions | PCBA: 88x57mm \| Assembled: ~100x60x60mm |
| Per-Module Power | 1.2W idle / 2.6W load / 3.7W peak |

### Power Budget (7x LM3H)

| Load Scenario | Total Power |
|---------------|-------------|
| All idle | ~3.6W + (7 x 1.2W) = **12W** |
| All at load | ~3.6W + (7 x 2.6W) = **21.8W** |
| All at peak | ~3.6W + (7 x 3.7W) = **29.5W** |
| PD max capacity | **60W** (20V/3A) / 65W with e-Marker cable |
| Headroom | **~40% at peak** — well within budget |

### Cluster-to-Switch Port Mapping

| NanoCluster Slot | JL6108 Switch Port | Node Role |
|:----------------:|:------------------:|-----------|
| Slot 1 | Port 7 | node1 (Manager + Gluster) |
| Slot 2 | Port 6 | node2 (Manager + Gluster) |
| Slot 3 | Port 5 | node3 (Manager + Gluster) |
| Slot 4 | Port 4 | node4 (Worker) |
| Slot 5 | Port 3 | node5 (Worker) |
| Slot 6 | Port 2 | node6 (Worker) |
| Slot 7 | Port 1 | node7 (Worker) |
| RJ45 (backplane) | Port 8 | External network uplink |

---

## 2. OS & Image

### Official Images (Debian-based)

| Image | Download | Default Credentials |
|-------|----------|-------------------|
| Debian Desktop | [Baidu](https://pan.baidu.com/s/1VGaARAq6dbicFy4VOytRuw) (code: cd68) / [MEGA](https://mega.nz/folder/gt50zDoC#LgRvHVCzWTUgGohKoMtlqA) | `sipeed` / `licheepi` or `root` / `root` |
| Debian CLI | Same links | Same |

**Changelog highlights:**
- `20240106` — Added eMMC boot support
- `20240110` — SD/eMMC bootable images, fixed DNS
- `20240226` — GPIO sysfs, SSH root login, USB gadget
- `20240407` — Debian CLI image added

### Alternative: Ubuntu / Armbian

- **Ubuntu 22.04** — Build from SDK: `mkrootfs-ubuntu-cli.sh` in [LonganPi-3H-SDK](https://github.com/sipeed/LonganPi-3H-SDK)
- **Armbian** — Community porting thread active. Known thermal shutdown issue with mainline kernel (`CONFIG_THERMAL=y`). See Thermal section below.

### Recommended OS for This Project

**Official Debian image (20240407+)** — CLI variant to save resources. Rationale:
- Pre-tested Docker compatibility on H618
- No thermal false-shutdown bug (vendor kernel has `CONFIG_THERMAL` disabled)
- eMMC boot support since 20240106
- Minimal resource footprint (CLI only)

### Flashing Procedure

#### To eMMC (recommended — no SD card dependency)

1. Flash Debian CLI image to SD card via balenaEtcher (image >= 20240106)
2. Insert SD card into module, power on, login
3. SCP the eMMC image to the running system
4. Write to eMMC:
   ```bash
   sudo dd if=./image.img of=/dev/mmcblk1 bs=4M status=progress conv=fsync
   ```
5. Power off, remove SD card, power on — boots from eMMC

#### To SD card only (fallback)

1. Flash image to SD card via balenaEtcher
2. Insert into module

### Boot Modes

| Mode | Trigger | Use Case |
|------|---------|----------|
| Normal boot | Power on | Standard operation |
| UMS mode (USB mass storage) | Hold BOOT + power on (Slot 1) | Reflash eMMC from PC |
| FEL mode | Short slot1 pin to GND + power on | Emergency U-Boot recovery |

### mDNS Discovery

All modules ship with mDNS enabled. After network connection:
```bash
avahi-browse -a
ssh sipeed@lpi3h.local  # default hostname prefix
```

---

## 3. Networking

### Critical: LM3H Ethernet is 100M Only

The LM3H's on-board Ethernet controller is **Fast Ethernet (100 Mbps)**, NOT Gigabit despite the baseboard's JL6108 being a Gigabit switch. This means:
- Inter-node Swarm traffic is limited to 100 Mbps half-duplex per link
- GlusterFS replication between managers is capped at ~10 MB/s
- For production workloads, expect bandwidth-limited performance

### JL6108 Internal Switch

| Feature | Details |
|---------|---------|
| Chip | JL6108 RISC-V Gigabit Switch |
| Default IP | `10.10.11.10/24` |
| Login | `admin` / `admin` |
| Web UI | `http://10.10.11.10` (Windows recommended — Linux compatibility issues) |
| VLAN support | Port-based, MTU, 802.1Q, PVID |
| QoS | Port-based, 802.1P, DSCP |
| Advanced | Port aggregation, loop protection, broadcast storm suppression |

### Network Topology for This Cluster

```
[External Router] ←→ RJ45 uplink ←→ JL6108 Switch ←→ Slots 1-7 (100M each)
                                                    |
                                          All 7 modules on same L2 broadcast domain
```

All 7 nodes share the same L2 network through the JL6108. They appear as separate MAC addresses to the external router and can have independent IPs on the external network's subnet.

### Static IP Assignment

For static IPs (192.168.1.11–17), configure on each node:

```yaml
# /etc/network/interfaces (Debian)
auto eth0
iface eth0 inet static
    address 192.168.1.11
    netmask 255.255.255.0
    gateway 192.168.1.1
    dns-nameservers 1.1.1.1 8.8.8.8
```

Or via Netplan (Ubuntu):
```yaml
# /etc/netplan/01-static.yaml
network:
  version: 2
  ethernets:
    eth0:
      addresses: [192.168.1.11/24]
      routes: [{to: default, via: 192.168.1.1}]
      nameservers: {addresses: [1.1.1.1, 8.8.8.8]}
```

### Network Considerations for Swarm Services

- **Pi-hole / WireGuard** require `network_mode: host` — they bypass the Swarm routing mesh entirely
- **VIP floating via Keepalived** works because all managers share the same L2 segment
- **100M bandwidth** is sufficient for DNS and VPN but will bottleneck large file transfers (e.g., Grafana dashboard data, GlusterFS replication of large containers)

---

## 4. Thermal Management

### Known Issues

| Issue | Details |
|-------|---------|
| **Armbian thermal false-shutdown** | Mainline kernel (`CONFIG_THERMAL=y`) misreads thermal zones → immediate shutdown on boot. Vendor kernel has `CONFIG_THERMAL` disabled. |
| **CPU frequency throttling** | System automatically reduces CPU frequency when idle or when temperature exceeds thresholds. |
| **Slot 7 edge position** | Lower airflow — install larger heatsink |

### Thermal Mitigations

```bash
# Check current thermal state
cat /sys/class/thermal/thermal_zone0/temp  # in millidegrees C

# Fan speed control (0=auto, 1-4=manual)
echo 0 > /sys/class/thermal/thermal_zone0/policy  # auto (default)
echo 3 > /sys/class/thermal/thermal_zone0/policy  # manual speed 3/4

# CPU frequency (check current governor)
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
```

### Physical Cooling Checklist

- [ ] Heatsink attached to each module (shipped pre-installed)
- [ ] Fan airflow points toward Ethernet port
- [ ] Slot 7 has larger heatsink
- [ ] Ambient temperature < 30°C
- [ ] Case has adequate ventilation

### Temperature Expectations

- Idle cluster: ~45-50°C per module
- Under load: ~55-60°C
- Thermal throttling: ~65-70°C (frequency reduction)
- Shutdown threshold: ~85-90°C (if not mitigated)

---

## 5. Docker on LM3H

### Architecture

| Property | Value |
|----------|-------|
| Architecture | `linux/arm64` (aarch64) |
| Docker Support | ✅ Official ARM64 images widely available |
| Docker Compose | ✅ Full support |
| Docker Swarm | ✅ Full support |

### Image Availability

| Service | ARM64 Support | Notes |
|---------|---------------|-------|
| Portainer CE | ✅ | Official `linux/arm64` manifest |
| InfluxDB 2.7 | ✅ | Official `linux/arm64` image |
| Grafana | ✅ | Official `linux/arm64` image |
| Telegraf | ✅ | Official `linux/arm64` image |
| Pi-hole | ✅ | Official `linux/arm64` image |
| WireGuard (linuxserver) | ✅ | Official `linux/arm64` image |
| Keepalived (linuxserver) | ✅ | Official `linux/arm64` image |
| UniFi Controller | ❌ | Linuxserver image is amd64 only — see Workaround |

### UniFi Controller Workaround

The official UniFi Network Application is Java-based and available for ARM64, but the `linuxserver/unifi-controller` image does not support arm64.

**Options:**
1. **Official UBNT Docker image:** `docker pull lscr.io/linuxserver/unifi-network-application` — check if arm64 is supported in newer versions
2. **Manual install:** Download ARM64 .deb from Ubiquiti, run in a Debian-based container
3. **Skip if not needed:** Not all clusters require UniFi management

### Docker Installation on Debian (LM3H)

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker sipeed
sudo systemctl enable docker
```

### Docker Storage Driver

The default `overlay2` driver works on the LM3H's Debian rootfs (ext4 on eMMC).

### Container Resource Limits

With 4GB RAM per module and ~200MB system overhead:
- Reserve ~500MB per module for OS + Swarm agent + GlusterFS daemon
- Allow ~3.3GB for user containers per module
- Set memory limits in compose files to prevent OOM kills

---

## 6. GlusterFS on LM3H

### Compatibility

GlusterFS runs on ARM64 Linux. The Debian packages are available in `apt`:

```bash
sudo apt install glusterfs-server
```

### Storage Considerations

| Factor | Value |
|--------|-------|
| eMMC per module | 32GB |
| OS + Docker usage | ~8-10GB (estimated) |
| Available for GlusterFS | ~20-22GB per brick |
| 3-way replica volume | ~20-22GB usable (mirrored across 3 managers) |

### GlusterFS Brick Path

Each manager node (node1, node2, node3) exposes a brick at:
```
/var/lib/gluster/bricks/swarm-storage
```

### Performance Note

With 100M Ethernet and eMMC storage, GlusterFS replication will be I/O and bandwidth limited. Expected replication speed: ~10 MB/s. For the cluster's use case (Docker volumes, config files, database data), this is acceptable.

### Mount Configuration

```bash
# /etc/fstab on all 7 nodes
127.0.0.1:/swarm-storage /gluster-mount glusterfs defaults,_netdev 0 0
```

### GlusterFS Service Management

```bash
sudo systemctl enable glusterd
sudo systemctl start glusterd
```

---

## 7. SSH & Serial Access

### SSH Configuration

| Property | Value |
|----------|-------|
| Default user | `sipeed` (password: `licheepi`) |
| Root SSH | Enabled since image 20240226 (password: `root`) |
| mDNS hostname | `lpi3h.local` (may have suffixes for multi-node) |

### SSH Key Setup (Bootstrap Phase)

The `bootstrap/bootstrap-node.sh` script:
1. Reads node credentials from `ansible/inventory`
2. Uses `sshpass` to copy the control machine's public key to all nodes
3. Retries failed nodes up to 5 times
4. Requires `sshpass` installed on the control machine:
   ```bash
   sudo apt install sshpass
   ```

### Serial Debugging

Each module exposes a 2.54mm UART header:
- **Baud rate:** 115200
- **Wiring:** Cross RX/TX, connect GND
- **Tools:** `picocom`, `minicom`, `XShell`
- **Multi-module:** USB-to-4-serial expansion board consolidates slots 3,5,6,7 to slot1
- **Limit:** Max 4-5 serial connections for cooling stability

### Serial Ports

| Port | Pins | Purpose |
|------|------|---------|
| UART0 | U0-RX, U0-TX | System console |
| UART1-4 | General headers | Application use |

---

## 8. Power Control & GPIO

### Reset Control via Slot 1

All slot resets are controlled via I2C extended IO (PCA9557) on Slot 1:

| GPIO Index | Function |
|:----------:|----------|
| 0 | Switch chip reset |
| 1 | Slot 1 reset |
| 2 | Slot 2 reset |
| 3 | Slot 3 reset |
| 4 | Slot 4 reset |
| 5 | Slot 5 reset |
| 6 | Slot 6 reset |
| 7 | Slot 7 reset |

```bash
# LM3H uses gpiochip2
# Low (0) = reset, High (1) = power on
sudo gpioset gpiochip2 1=1  # Power on slot 1
sudo gpioset gpiochip2 1=0  # Reset slot 1
```

### Remote Reboot via SSH

For Ansible automation, prefer `reboot` command over GPIO reset:
```bash
ssh sipeed@192.168.1.11 'sudo reboot'
```

---

## 9. Deployment Checklist

### Pre-Flight

- [ ] All 7 modules seated and heatsinks attached
- [ ] Fan installed (airflow toward Ethernet)
- [ ] Slot 7 has larger heatsink
- [ ] Debian CLI image (20240106+) flashed to all modules (eMMC preferred)
- [ ] All modules powered on and reachable via SSH
- [ ] mDNS discovery working: `avahi-browse -a`
- [ ] Static IPs assigned (or DHCP reserved)
- [ ] Control machine has `sshpass` installed
- [ ] `ansible/inventory` populated with all 7 node details
- [ ] Secret files populated in `secrets/` directory

### Deployment Phases

| Phase | Script | Purpose |
|-------|--------|---------|
| 1 | `bootstrap/bootstrap-node.sh` | SSH key distribution |
| 2a | `ansible/install_docker.yml` | Install Docker on all nodes |
| 2b | `ansible/init_swarm.yml` | Initialize Swarm cluster |
| 2c | `ansible/provision_gluster.yml` | GlusterFS setup |
| 3 | `scripts/setup.sh` | Labels, volumes, secrets |
| 4 | `scripts/deploy.sh` | Deploy all Docker stacks |

### Orchestration

```bash
cd /workspace/swarm-infra
sudo ./provision-cluster.sh
```

### Post-Deploy Verification

```bash
# Swarm status
ssh sipeed@node1 'docker node ls'

# GlusterFS volume
ssh sipeed@node1 'gluster volume info swarm-storage'

# GlusterFS mount on all nodes
for i in $(seq 11 17); do
  ssh sipeed@192.168.1.$i 'df -h /gluster-mount'
done

# Running stacks
ssh sipeed@node1 'docker stack ls'

# VIP assignment (Keepalived)
ssh sipeed@node1 'ip addr show | grep 192.168.1.100'
```

---

## 10. Troubleshooting

### Common Issues

| Symptom | Likely Cause | Resolution |
|---------|-------------|------------|
| Module won't power on | PD adapter < 20V or insufficient power | Use 20V PD adapter, check green/blue LEDs |
| Module boots then shuts down | Thermal false positive (Armbian) | Switch to official Debian image |
| No network after boot | Ethernet plugged in after boot | Plug Ethernet BEFORE powering on |
| GlusterFS mount fails | `glusterd` not running | `sudo systemctl start glusterd` on managers |
| Swarm join fails | Firewall blocking ports | Ensure ports 2377, 7946, 4789 are open |
| Keepalived VIP not floating | `ha.candidate` label missing | Verify with `docker node inspect node1` |
| Pi-hole/WireGuard unreachable | VIP not assigned | Check Keepalived logs: `docker service logs ha_keepalived` |
| Docker OOM kills | Container exceeds available RAM | Set memory limits in compose files |
| SSH key bootstrap fails | `sshpass` not installed | `sudo apt install sshpass` on control machine |
| eMMC write error | Image version < 20240106 | Use newer image for eMMC flashing |

### Debug Commands

```bash
# Check thermal state
cat /sys/class/thermal/thermal_zone0/temp

# Check Docker daemon logs
sudo journalctl -u docker.service --no-pager -n 50

# Check Swarm manager logs
docker service logs <service_name>

# Check GlusterFS health
gluster volume health-check swarm-storage detail

# Check Keepalived state
docker service ps ha_keepalived --no-trunc

# Network connectivity test
ping -c 3 192.168.1.11  # from any node
```

---

## 11. Performance Expectations

### Cluster-wide Resources

| Resource | Total | Per Node | Usable for Services |
|----------|-------|----------|-------------------|
| CPU Cores | 28 | 4x A53 @ 1.5GHz | ~24 cores (4 reserved for system) |
| RAM | 28GB | 4GB | ~24GB (500MB/node system reserve) |
| Storage | 224GB | 32GB eMMC | ~140GB (20GB/node for GlusterFS) |
| Network | 100M per link | 100M Ethernet | 100M half-duplex per module |

### GlusterFS Usable Storage

- 3 nodes × ~22GB = ~66GB raw brick space
- 3-way replica → ~22GB usable (each file stored 3x)
- Suitable for: Docker volumes, databases, config files, monitoring data

---

## 12. Reference Links

| Resource | URL |
|----------|-----|
| NanoCluster Wiki | https://wiki.sipeed.com/hardware/en/cluster/NanoCluster/index.html |
| Quick Start Guide | https://wiki.sipeed.com/hardware/en/cluster/NanoCluster/use.html |
| JL6108 Switch Docs | https://wiki.sipeed.com/hardware/en/cluster/NanoCluster/switch.html |
| LM3H Hardware Docs | https://dl.sipeed.com/shareURL/LONGAN/LonganPi3H |
| LM3H SDK | https://github.com/sipeed/LonganPi-3H-SDK |
| Official Images | https://wiki.sipeed.com/hardware/en/longan/h618/lpi3h/3_images.html |
| Mainline Linux Guide | https://wiki.sipeed.com/hardware/en/longan/h618/lpi3h/7_develop_mainline.html |
| Armbian Forum | https://forum.armbian.com/topic/33449-sipeed-longanpi-3h/ |
| NanoCluster GitHub | https://github.com/sipeed/NanoCluster |
