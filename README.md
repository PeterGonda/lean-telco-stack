# Lean Telco Stack: Edge Computing & Monitoring Simulation

A practical lab simulating a real-world telecommunications edge infrastructure,
where modern Kubernetes microservices coexist with a standalone legacy server.

## System Architecture

The project uses a hybrid architecture running entirely inside WSL2 on Windows.

### Networking & Infrastructure

| Component | Detail |
| :--- | :--- |
| Host OS | Windows 11 + WSL2 (Ubuntu) |
| Network | Fixed subnet `10.10.0.0/24` — predictable IPs for all nodes |
| Orchestration | `k3d` cluster — 1 Server (Control-Plane) + 3 Agents |
| Edge Gateway | Custom Nginx `worker-proxy` — default Traefik LB disabled via `--no-lb` |
| Legacy Node | Standalone Alpine container at `10.10.0.6` — outside Kubernetes |

### Node Specifications

| Node | OS Image | IP | Role | Managed by |
| :--- | :--- | :--- | :--- | :--- |
| control-plane | Ubuntu (k3s) | 10.10.0.2 | API Server, Scheduler | k3d |
| worker-db | AlmaLinux 9 | 10.10.0.3 | MariaDB database | Ansible (kubectl plugin) |
| worker-app | Debian 12 slim | 10.10.0.4 | Python Flask app | Kubernetes Deployment |
| worker-proxy | Ubuntu (Nginx) | 10.10.0.5 | Reverse proxy / gateway | Kubernetes Deployment |
| legacy-node | Alpine 3.18 | 10.10.0.6 | Simulated legacy server | Ansible (SSH) |

## Deployment Steps

```bash
# 1. Build the infrastructure (network + k3d cluster + legacy-node)
bash k3d-cluster.sh

# 2. Build and import the Flask app image into k3d
docker build -t worker-app:latest ./docker/worker-app/
k3d image import worker-app:latest -c telco-lab

# 3. Apply all Kubernetes manifests
kubectl apply -f k8s/

# 4. Configure Worker-DB via Ansible
ansible-playbook -i ansible/inventory.ini ansible/playbooks/configure-db.yaml

# 5. Apply hardening to all nodes
ansible-playbook -i ansible/inventory.ini ansible/playbooks/hardening.yaml

# 6. Start the monitoring suite
python3 monitoring/monitor.py &
bash monitoring/log-harvester.sh
```

## Automation & Configuration Management

Ansible manages the entire stack with idempotent playbooks.
k3d Pods are configured via the `ansible_connection=kubectl` plugin —
no SSH server is required inside the containers.
The Legacy-Node is configured via standard SSH.

## Monitoring & Self-Healing

### Log Harvester (Bash)
`monitoring/log-harvester.sh` aggregates logs from all nodes every 30 seconds:
- **k3d Pods** — collected via `kubectl logs deployment/<name>`
- **Legacy-Node** — collected via `docker logs legacy-node`

Output: `/var/log/telco-cluster.log`

### Python Health Monitor
`monitoring/monitor.py` uses the `kubernetes-python` client to:
- Track **Pod** health (`list_namespaced_pod`) — not Node health
- Auto-restart `worker-app` via `kubectl rollout restart` on failure
- Write a JSON health snapshot to `/tmp/telco-health.json`

## Lessons Learned (V1 → V2 → V3)

### 1. Load Balancer conflict
**Problem:** Traefik (default k3d LB) conflicted with our custom Nginx gateway.
**Solution:** `--no-lb` flag in `k3d-cluster.sh`. All traffic routed through `worker-proxy`.

### 2. Ansible SSH into k3d Pods
**Problem:** k3d containers have no SSH server — standard Ansible connection failed.
**Solution:** `ansible_connection=kubectl` plugin with dynamic Pod name lookup via `lookup('pipe', 'kubectl get pod ...')`.

### 3. MariaDB in a container without systemd
**Problem:** `service mariadb start` relies on systemd which does not run in containers.
**Solution:** Manual init via `mysql_install_db` + background start via `nohup mariadbd-safe`.

### 4. kubectl under sudo loses KUBECONFIG
**Problem:** `sudo` changes HOME to `/root` — kubectl could not find `~/.kube/config`.
**Solution:** Explicit `export KUBECONFIG=/home/asus/.kube/config` at the top of `log-harvester.sh`.

### 5. docker logs does not work for k3d Pods
**Problem:** k3d names its internal containers `k3d-telco-lab-agent-0`, not `worker-db`.
**Solution:** Use `kubectl logs deployment/worker-db` for k3d Pods. `docker logs` only for `legacy-node`.

### 6. Monitor was watching Nodes instead of Pods
**Problem:** If a Flask Pod crashes, the Node stays `Ready` — `list_node()` would not detect it.
**Solution:** Monitor uses `list_namespaced_pod()` and checks `container_statuses[].ready`.

---
*Developed by Peter Gonda — Mendelu Brno, IS/ICT Administration, 2025/2026*
