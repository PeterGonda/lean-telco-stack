# monitoring/monitor.py
# Real-time health monitor using the kubernetes-python client
#
# KEY FIX (V2): Monitors PODS not NODES.
# If the Flask Pod crashes, the Node remains 'Ready' —
# only list_namespaced_pod() detects the actual application failure.
#
# KEY FIX (V2): Logs written to /tmp instead of /var/log
# to avoid permission errors in WSL environments.
from kubernetes import client, config
import subprocess, time, json, logging, datetime

log_file    = '/tmp/telco-monitor.log'
report_file = '/tmp/telco-health.json'

logging.basicConfig(
    filename=log_file,
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s'
)

# Load kubeconfig from the default location (~/.kube/config)
config.load_kube_config()
v1 = client.CoreV1Api()


def get_pod_health():
    """Returns health status for all Pods in the default namespace."""
    pods = v1.list_namespaced_pod(namespace='default')
    report = []
    for pod in pods.items:
        report.append({
            'pod':   pod.metadata.name,
            'phase': pod.status.phase,
            # ready = True only if ALL containers inside the Pod are ready
            'ready': all(
                c.ready for c in (pod.status.container_statuses or [])
            )
        })
    return report


def get_node_health():
    """Returns Ready/NotReady status for all cluster Nodes."""
    nodes = v1.list_node()
    report = []
    for n in nodes.items:
        for c in n.status.conditions:
            if c.type == 'Ready':
                report.append({
                    'node':   n.metadata.name,
                    'status': c.status
                })
    return report


def restart_app():
    """Triggers a rolling restart of the worker-app Deployment."""
    logging.warning('Worker-App Pod DOWN — triggering kubectl rollout restart')
    subprocess.run([
        'kubectl', 'rollout', 'restart',
        'deployment/worker-app'
    ])
    print("[!] Worker-App is down! Restart command has been sent.")


def save_report(pods, nodes):
    """Writes the current health snapshot to a JSON file."""
    with open(report_file, 'w') as f:
        json.dump({
            'timestamp': str(datetime.datetime.now()),
            'pods':  pods,
            'nodes': nodes
        }, f, indent=2)


print("Starting Python Monitoring (press Ctrl+C to stop)...")

while True:
    try:
        pods  = get_pod_health()
        nodes = get_node_health()

        for pod in pods:
            # Detect any worker-app Pod that is not ready
            if pod['pod'].startswith('worker-app') and not pod['ready']:
                logging.warning(f"Pod {pod['pod']} not ready — restarting")
                restart_app()

        save_report(pods, nodes)

        msg = (f"[{datetime.datetime.now().strftime('%H:%M:%S')}] "
               f"Check: {len(pods)} pods, {len(nodes)} nodes. All OK.")
        print(msg)
        logging.info(msg)
        time.sleep(60)

    except Exception as e:
        print(f"Error during monitoring: {e}")
        time.sleep(10)
