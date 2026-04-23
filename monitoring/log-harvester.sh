#!/bin/bash
# monitoring/log-harvester.sh

# Dynamically resolve the current user's kubeconfig
# Works on any machine regardless of username
export KUBECONFIG="/home/$(logname)/.kube/config"

LOG_FILE="/var/log/telco-cluster.log"
INTERVAL=30

sudo touch $LOG_FILE
sudo chmod 666 $LOG_FILE

echo "[$(date)] Log harvester started" >> $LOG_FILE

while true; do
    echo "" >> $LOG_FILE
    echo "=== k3d pods | $(date) ===" >> $LOG_FILE

    for POD in worker-db worker-app worker-proxy; do
        echo "--- $POD ---" >> $LOG_FILE
        kubectl logs deployment/$POD --tail=20 2>&1 >> $LOG_FILE
    done

    echo "--- legacy-node ---" >> $LOG_FILE
    sudo docker logs --tail=20 legacy-node 2>&1 >> $LOG_FILE

    sleep $INTERVAL
done
