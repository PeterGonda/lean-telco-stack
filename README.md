# 📡 Lean Telco Stack: Edge Computing & Monitoring Simulation

This technical report documents the implementation of a simulated Telecommunications Edge infrastructure.

## 🏗 System Architecture
The project utilizes a hybrid architecture to reflect real-world telco scenarios where modern 

### 🌐 Networking & Infrastructure
- **Infrastructure:** OS Windows 10 + WSL2 (Ubuntu)
- **Network:** Fixed subnet `10.10.0.0/24` for predictable inter-node communication.
- **Orchestration:** `k3d` cluster with 1 Server and 3 Agents.
- **Edge Gateway:** Custom Nginx `worker-proxy` (default Load Balancer disabled via `--no-lb`).
- **Legacy Node:** Standalone Alpine Linux container (`10.10.0.6`) running outside the cluster.

### 📦 Node Specifications
| Node | OS Image | Role | Management |
| :--- | :--- | :--- | :--- |
| **control-plane** | Ubuntu (k3s) | API Server | k3d |
| **worker-db** | AlmaLinux 9 | MariaDB | Ansible (kubectl) |
| **worker-app** | Debian 12 | Flask App | Kubernetes |
| **worker-proxy** | Ubuntu | Nginx Proxy | Kubernetes |
| **legacy-node** | Alpine 3.18 | Legacy Server | Ansible (SSH) |

## 🛠 Automation & Configuration Management
We use **Ansible** for idempotent configuration of the entire stack.

### Key Improvements in Version 2:
- **MariaDB Initialization:** Since containers lack `systemd`, the `configure-db.yaml` playbook was updated to manually initialize system tables and manage the `mariadbd-safe` process in the background.
- **Kubectl Connection Plugin:** Ansible connects to pods directly via `kubectl exec`, eliminating the security overhead of running SSH servers inside microservices.
- **Ansible Optimization:** Pipelining is enabled and Fact Gathering is disabled to ensure maximum speed and stability across the virtual network.

## 📊 Monitoring & Self-Healing Logic
The project features a custom-built monitoring suite designed for centralized visibility.

### 1. Unified Log Harvester (Bash)
Aggregates logs from disparate sources:
- **K8s Pods:** Collected via `kubectl logs`.
- **Standalone Containers:** Collected via `docker logs`.
- **Fix:** Uses explicit `KUBECONFIG` export to allow `sudo` execution in automated environments.

### 2. Python Health Dashboard
A real-time monitoring script using the `kubernetes-python` client:
- Tracks `Pod` and `Node` status.
- **Auto-Healing:** Upon detecting a failure in the `worker-app`, it triggers a rolling restart of the deployment to maintain 100% availability.

## 🚀 Deployment Summary
1. **Infrastructure:** `bash k3d-cluster.sh`
2. **K8s Deployments:** `kubectl apply -f k8s/`
3. **App Build:** `docker build -t worker-app:latest ./docker/worker-app/`
4. **Configuration:** `ansible-playbook -i ansible/inventory.ini ansible/playbooks/configure-db.yaml`
5. **Monitoring:** `python3 monitoring/monitor.py`

## 🛠 Troubleshooting & Lessons Learned
Developing this stack required solving several production-like challenges, addressed in the **v2** iteration of the code:

### 1. Networking Strategy
- [cite_start]**Challenge:** Default Kubernetes load balancers (Traefik) automatically handle traffic, which is not suitable for strictly controlled Edge environments.
- [cite_start]**Solution:** Disabled the default LB via the `--no-lb` flag in `k3d-cluster.sh`. [cite_start]This forces traffic through a manually configured Nginx proxy, mirroring real telco gateway deployments.

### 2. Connectivity without SSH
- [cite_start]**Challenge:** Ansible typically requires SSH, but modern Kubernetes Pods are minimal and do not run SSH servers.
- [cite_start]**Solution:** Configured `ansible_connection=kubectl` in the inventory[cite: 213, 1064]. [cite_start]This allows Ansible to execute tasks via the Kubernetes API without adding extra security overhead to the containers[cite: 219].

### 3. Database Deployment in Minimal Containers
- [cite_start]**Challenge:** `systemd` is unavailable in standard AlmaLinux container images, making the standard `service` module in Ansible useless.
- [cite_start]**Solution:** Used `mysql_install_db` for manual initialization and `nohup` for background process management within the Ansible playbook.

### 4. Logging & Monitoring Permissions
- [cite_start]**Challenge:** Monitoring scripts running as `root` (via sudo) could not locate the user's `KUBECONFIG`, leading to authentication failures[cite: 137, 870].
- [cite_start]**Solution:** Explicitly exported the `KUBECONFIG` path in `log-harvester.sh` and set appropriate file permissions for centralized logs in `/var/log/`.

## 📊 Self-Healing Capabilities
The included **Python Monitor** tracks pod health in real-time. [cite_start]If the application pod fails, the script automatically triggers a `kubectl rollout restart`, demonstrating automated service recovery [cite: 830-836, 856].

---
*Developed by Peter Gonda as a practical lab for self studie purposes.*
