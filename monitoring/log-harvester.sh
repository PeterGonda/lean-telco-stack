#!/bin/bash
# monitoring/log-harvester.sh

# --- TOTO JE TÁ HLAVNÁ OPRAVA ---
# THIS IS THE MAIN FIX
# A script running under sudo needs to know where your user (asus) has the K8s configuration located.
export KUBECONFIG=/home/asus/.kube/config
# --------------------------------

LOG_FILE="/var/log/telco-cluster.log"
INTERVAL=30

# Create file if it doesn't exist and set permissions to avoid access errors
sudo touch $LOG_FILE
sudo chmod 666 $LOG_FILE

echo "[$(date)] Log harvester started" >> $LOG_FILE

while true; do
  echo "" >> $LOG_FILE
  echo "=== k3d pods | $(date) ===" >> $LOG_FILE

  # k3d pods — # Fetching logs from Kubernetes deployments using kubectl (not docker logs!)
  for POD in worker-db worker-app worker-proxy; do
    echo "--- $POD ---" >> $LOG_FILE
    kubectl logs deployment/$POD --tail=20 2>&1 >> $LOG_FILE
  done

  # Legacy-Node — standalone Docker container, docker logs work here
  echo "--- legacy-node ---" >> $LOG_FILE
  # Added sudo just in case to prevent Docker from denying background access
  sudo docker logs --tail=20 legacy-node 2>&1 >> $LOG_FILE

  sleep $INTERVAL
done