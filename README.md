# Lean Telco Stack: Edge Computing & Monitoring Simulation

A practical lab simulating a real-world telecommunications edge infrastructure,
where modern Kubernetes microservices coexist with a standalone legacy server.

## System Architecture

The project runs entirely inside WSL2 on Windows using a hybrid architecture.

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

## Prerequisites

Install these before running the project:

```bash
# Ansible kubectl connection plugin
ansible-galaxy collection install kubernetes.core

# Python Kubernetes client
pip3 install kubernetes
```

## Deployment Steps

Run these commands in order — sequence matters.

```bash
# 1. Build the full infrastructure
#    (network + k3d cluster + legacy-node + SSH on legacy-node)
bash k3d-cluster.sh

# 2. Build the Flask app Docker image
docker build -t worker-app:latest ./docker/worker-app/

# 3. Import the image into k3d (REQUIRED — imagePullPolicy: Never)
#    Without this step, worker-app Pod will enter ImagePullBackOff
k3d image import worker-app:latest -c telco-lab

# 4. Apply all Kubernetes manifests
kubectl apply -f k8s/

# 5. Wait until all Pods are Running before proceeding
kubectl get pods -w

# 6. Configure MariaDB on Worker-DB via Ansible
ansible-playbook -i ansible/inventory.ini ansible/playbooks/configure-db.yaml

# 7. Apply hardening to all nodes
ansible-playbook -i ansible/inventory.ini ansible/playbooks/hardening.yaml

# 8. Start the monitoring suite
python3 monitoring/monitor.py &
bash monitoring/log-harvester.sh
```

## Accessing the Application

Since the default Load Balancer is disabled (`--no-lb`), use port-forward
to reach the Nginx proxy from your local machine:

```bash
kubectl port-forward deployment/worker-proxy 8080:80
```

Then open in your browser or curl:

```bash
curl http://localhost:8080/health
curl http://localhost:8080/api/data
```

## Automation & Configuration Management

Ansible manages the entire stack with idempotent playbooks.

- **k3d Pods** — configured via `ansible_connection=kubectl` plugin.
  No SSH server is required inside the containers.
- **Legacy-Node** — configured via standard SSH.
  OpenSSH is installed automatically by `k3d-cluster.sh`.

## Monitoring & Self-Healing

### Log Harvester (Bash)
`monitoring/log-harvester.sh` aggregates logs from all nodes every 30 seconds:
- **k3d Pods** — collected via `kubectl logs deployment/<name>`
- **Legacy-Node** — collected via `docker logs legacy-node`

Output: `/var/log/telco-cluster.log`

### Python Health Monitor
`monitoring/monitor.py` uses the `kubernetes-python` client to:
- Track **Pod** health via `list_namespaced_pod()` — not Node health
- Auto-restart `worker-app` via `kubectl rollout restart` on failure
- Write a JSON health snapshot to `/tmp/telco-health.json`

> **Why Pods and not Nodes?**
> If the Flask Pod crashes, the underlying Node stays `Ready`.
> Monitoring Nodes would never detect an application-level failure.

## Lessons Learned (V1 → V2 → V3)

### 1. Load Balancer conflict
**Problem:** Traefik (default k3d LB) conflicted with our custom Nginx gateway.  
**Solution:** `--no-lb` flag in `k3d-cluster.sh`. All traffic routed through `worker-proxy`.

### 2. Ansible SSH into k3d Pods
**Problem:** k3d containers have no SSH server — standard Ansible connection failed.  
**Solution:** `ansible_connection=kubectl` plugin with dynamic Pod name lookup.

### 3. MariaDB in a container without systemd
**Problem:** `service mariadb start` relies on systemd which does not run in containers.  
**Solution:** Manual init via `mysql_install_db` + background start via `nohup mariadbd-safe`.

### 4. kubectl under sudo loses KUBECONFIG
**Problem:** `sudo` changes HOME to `/root` — kubectl cannot find `~/.kube/config`.  
**Solution:** `export KUBECONFIG="/home/$(logname)/.kube/config"` — works on any machine.

### 5. docker logs does not work for k3d Pods
**Problem:** k3d names its containers `k3d-telco-lab-agent-0`, not `worker-db`.  
**Solution:** `kubectl logs deployment/worker-db` for k3d Pods. `docker logs` only for `legacy-node`.

### 6. Monitor was watching Nodes instead of Pods
**Problem:** If a Flask Pod crashes, the Node stays `Ready` — `list_node()` misses it.  
**Solution:** `list_namespaced_pod()` with `container_statuses[].ready` check.

### 7. worker-app image not available in k3d
**Problem:** `imagePullPolicy: Never` means k3d will not pull from Docker Hub.  
**Solution:** `k3d image import worker-app:latest -c telco-lab` after `docker build`.

### 8. Legacy-Node had no SSH
**Problem:** Alpine does not include SSH — Ansible could not connect via SSH.  
**Solution:** `k3d-cluster.sh` installs openssh and starts sshd automatically after container start.

---
*Developed by Peter Gonda — Mendelu Brno, IS/ICT Administration, 2025/2026*
