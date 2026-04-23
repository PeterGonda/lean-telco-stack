# monitoring/monitor.py
from kubernetes import client, config
import subprocess, time, json, logging, datetime, os

# Logging configuration with write permissions to a local folder (safe for WSL)
log_file = '/tmp/telco-monitor.log'
report_file = '/tmp/telco-health.json'

logging.basicConfig(
    filename=log_file,
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s'
)

# Load configuration directly from the default location (~/.kube/config)
config.load_kube_config()
v1 = client.CoreV1Api()

def get_pod_health():
    pods = v1.list_namespaced_pod(namespace='default')
    report = []
    for pod in pods.items:
        report.append({
            'pod': pod.metadata.name,
            'phase': pod.status.phase,
            'ready': all(
                c.ready for c in (pod.status.container_statuses or [])
            )
        })
    return report

def get_node_health():
    nodes = v1.list_node()
    report = []
    for n in nodes.items:
        for c in n.status.conditions:
            if c.type == 'Ready':
                report.append({
                    'node': n.metadata.name,
                    'status': c.status
                })
    return report

def restart_app():
    logging.warning('Worker-App Pod DOWN — triggering kubectl rollout')
    subprocess.run([
        'kubectl', 'rollout', 'restart',
        'deployment/worker-app'
    ])
    print("[!] Worker-App is down! Restart command has been sent.")

def save_report(pods, nodes):
    with open(report_file, 'w') as f:
        json.dump({
            'timestamp': str(datetime.datetime.now()),
            'pods': pods,
            'nodes': nodes
        }, f, indent=2)

print("Starting Python Monitoring (press Ctrl+C to stop)...")
while True:
    try:
        pods = get_pod_health()
        nodes = get_node_health()
        for pod in pods:
            # Look for pods starting with 'worker-app'
            if pod['pod'].startswith('worker-app') and not pod['ready']:
                logging.warning(f"Pod {pod['pod']} not ready — restarting")
                restart_app()
        save_report(pods, nodes)
        msg = f"[{datetime.datetime.now().strftime('%H:%M:%S')}] Check: {len(pods)} pods, {len(nodes)} nodes running. All OK."
        print(msg)
        logging.info(msg)
        time.sleep(60)
    except Exception as e:
        print(f"Error during monitoring: {e}")
        time.sleep(10)