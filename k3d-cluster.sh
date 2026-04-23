#!/bin/bash

# =============================================================
# k3d-cluster.sh
# Main bootstrap script for the Lean Telco Stack infrastructure
# Run this first before any other step
# =============================================================

# Step 1: Deep cleaning of any previous attempts
# The '|| true' prevents the script from stopping if resources don't exist yet
echo "Step 1: Deep cleaning..."
k3d cluster delete telco-lab || true
docker rm -f legacy-node || true
docker network rm telco-net || true

# Step 2: Create a dedicated Docker network with a fixed subnet
# Fixed subnet ensures predictable IP addresses for all nodes
echo "Step 2: Creating network 10.10.0.0/24..."
docker network create telco-net --subnet=10.10.0.0/24

# Step 3: Start Legacy-Node FIRST to reserve IP .6
# If k3d starts first, it will claim .6 for itself
echo "Step 3: Starting Legacy-Node on 10.10.0.6..."
docker run -d \
  --name legacy-node \
  --network telco-net \
  --ip 10.10.0.6 \
  alpine:3.18 sleep infinity

# Step 4: Install and configure SSH on Legacy-Node
# Alpine does not include SSH by default
# Ansible requires SSH to connect to this node (unlike k3d pods which use kubectl)
echo "Step 4: Installing and configuring SSH on Legacy-Node..."
docker exec legacy-node apk add --no-cache openssh

# Generate all required SSH host keys (rsa, ecdsa, ed25519)
docker exec legacy-node ssh-keygen -A

# Allow root login via SSH — required for Ansible access
# In a production environment this would be replaced with key-based auth
docker exec legacy-node sed -i \
  's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' \
  /etc/ssh/sshd_config

# Enable password authentication so Ansible can connect
docker exec legacy-node sed -i \
  's/#PasswordAuthentication yes/PasswordAuthentication yes/' \
  /etc/ssh/sshd_config

# Set root password for Ansible SSH access
docker exec legacy-node sh -c "echo 'root:telco123' | chpasswd"

# Start the SSH daemon
docker exec legacy-node /usr/sbin/sshd

# Step 5: Create k3d cluster WITHOUT the default Load Balancer
# --no-lb disables Traefik — all traffic is routed through our own Nginx proxy
# k3d will occupy addresses .2 through .5
echo "Step 5: Creating k3d cluster (Fixed IPs .2 to .5)..."
k3d cluster create telco-lab \
  --servers 1 \
  --agents 3 \
  --network telco-net \
  --no-lb

echo "------------------------------------------------"
echo "DONE! Network layout:"
echo "10.10.0.1 -> Gateway"
echo "10.10.0.2 -> k3d Server (Control-Plane)"
echo "10.10.0.3 -> k3d Agent 0 (Worker-DB)"
echo "10.10.0.4 -> k3d Agent 1 (Worker-App)"
echo "10.10.0.5 -> k3d Agent 2 (Worker-Proxy)"
echo "10.10.0.6 -> Legacy Node (standalone Docker + SSH)"
echo "------------------------------------------------"
echo ""
echo "NEXT STEPS:"
echo "  docker build -t worker-app:latest ./docker/worker-app/"
echo "  k3d image import worker-app:latest -c telco-lab"
echo "  kubectl apply -f k8s/"
echo "------------------------------------------------"
