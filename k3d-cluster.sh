#!/bin/bash

# 1. Full cleanup of previous attempts
echo "Step 1: Deep cleaning..."
k3d cluster delete telco-lab || true
docker rm -f legacy-node || true
docker network rm telco-net || true

# 2. Network creation
echo "Step 2: Creating network 10.10.0.0/24..."
docker network create telco-net --subnet=10.10.0.0/24

# 3. Starting Legacy-Node (Reserves .6 first)
echo "Step 3: Starting Legacy-Node on 10.10.0.6..."
docker run -d \
  --name legacy-node \
  --network telco-net \
  --ip 10.10.0.6 \
  alpine:3.18 sleep infinity

# 4. Starting k3d cluster WITHOUT Load Balancer (--no-lb). This ensures k3d only occupies addresses .2, .3, .4, and .5.
echo "Step 4: Creating k3d cluster (Fixed IPs .2 to .5)..."
k3d cluster create telco-lab \
  --servers 1 \
  --agents 3 \
  --network telco-net \
  --no-lb

echo "------------------------------------------------"
echo "DONE! Network layout is now fixed:"
echo "10.10.0.1 -> Gateway"
echo "10.10.0.2-5 -> k3d Nodes (Server + 3 Agents)"
echo "10.10.0.6 -> Legacy Node"
echo "------------------------------------------------"