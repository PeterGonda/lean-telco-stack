#!/bin/bash

# Step 1: Deep cleaning of any previous attempts
echo "Step 1: Deep cleaning..."
k3d cluster delete telco-lab || true
docker rm -f legacy-node || true
docker network rm telco-net || true

# Step 2: Create a dedicated Docker network with a fixed subnet
echo "Step 2: Creating network 10.10.0.0/24..."
docker network create telco-net --subnet=10.10.0.0/24

# Step 3: Start Legacy-Node FIRST to reserve IP .6
# If k3d starts first, it will claim this address
echo "Step 3: Starting Legacy-Node on 10.10.0.6..."
docker run -d \
  --name legacy-node \
  --network telco-net \
  --ip 10.10.0.6 \
  alpine:3.18 sleep infinity

# Step 4: Create k3d cluster WITHOUT the default Load Balancer
# --no-lb disables Traefik, forcing all traffic through our own Nginx proxy
# k3d will occupy addresses .2 through .5
echo "Step 4: Creating k3d cluster (Fixed IPs .2 to .5)..."
k3d cluster create telco-lab \
  --servers 1 \
  --agents 3 \
  --network telco-net \
  --no-lb

echo "------------------------------------------------"
echo "DONE! Network layout:"
echo "10.10.0.1 -> Gateway"
echo "10.10.0.2-5 -> k3d Nodes (Server + 3 Agents)"
echo "10.10.0.6 -> Legacy Node (standalone Docker)"
echo "------------------------------------------------"
