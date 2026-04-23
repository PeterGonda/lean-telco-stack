#!/bin/bash
# =============================================================
# monitoring/log-harvester.sh
# Centralizes logs from all nodes into a single file every 30s
#
# KEY FIX 1: docker logs does NOT work for k3d pods
#   k3d names internal containers 'k3d-telco-lab-agent-0' etc.
#   Use kubectl logs deployment/<name> for k3d pods instead.
#   docker logs only works for legacy-node (plain Docker container).
#
# KEY FIX 2: sudo changes HOME to /root
#   kubectl cannot find ~/.kube/config when running under sudo.
#   Solution: export KUBECONFIG explicitly using logname
#   to resolve the actual username dynamically.
#
# KEY FIX 3: /var/log/ requires elevated permissions
#   Solution: create the file with sudo and set open permissions (666)
#   so the script can write to it without running entirely as root.
#
# KEY FIX 4: hardcoded username replaced with $(logname)
#   $(logname) returns the name of the user who launched the script
#   even when running under sudo — works on any machine.
# =============================================================

# Dynamically resolve the current user's kubeconfig
# Works on any machine regardless of the username
export KUBECONFIG="/home/$(logname)/.kube/config"

LOG_FILE="/var/log/telco-cluster.log"
INTERVAL=30

# Create the log file if it does not exist
# Set open permissions so the script can write without full root access
sudo touch $LOG_FILE
sudo chmod 666 $LOG_FILE

echo "[$(date)] Log harvester started" >> $LOG_FILE
echo "[$(date)] Using KUBECONFIG: $KUBECONFIG" >> $LOG_FILE

while true; do
    echo "" >> $LOG_FILE
    echo "=== k3d pods | $(date) ===" >> $LOG_FILE

    # k3d Pods — must use kubectl logs, NOT docker logs
    # kubectl contacts the Kubernetes API which knows where each Pod runs
    for POD in worker-db worker-app worker-proxy; do
        echo "--- $POD ---" >> $LOG_FILE
        kubectl logs deployment/$POD --tail=20 2>&1 >> $LOG_FILE
    done

    # Legacy-Node — plain Docker container with a predictable name
    # docker logs works here because we named it explicitly with --name legacy-node
    echo "--- legacy-node ---" >> $LOG_FILE
    sudo docker logs --tail=20 legacy-node 2>&1 >> $LOG_FILE

    sleep $INTERVAL
done
