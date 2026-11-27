# Prometheus and Grafana using Kubernetes YAML

This is a learning/demo alternative to the Terraform + Helm monitoring stack. It runs in the separate `monitoring-yaml` namespace and uses distinct resource names. It does not replace or edit the existing Helm release in `monitoring`.

The demo expects the existing production NGINX service to have label `app=nginx`, a Service port named `metrics` on port `9113`, and the existing `ebs-gp3` StorageClass. The manifests also add a separate NetworkPolicy that allows this demo Prometheus to reach the NGINX exporter. Kubernetes NetworkPolicy allow rules are additive, so the existing monitoring policy remains in place.

## 1. Create a branch from `v3`

Run from the repository root:

```bash
git switch v3
git pull --ff-only origin v3
git switch -c monitoring-yaml-demo
```

Copy the `kubernetes/prod/07-monitoring-yaml-demo/` directory and this document into the repository at the same paths. Then review and publish the branch:

```bash
git status --short
git diff --check
git add kubernetes/prod/07-monitoring-yaml-demo docs/monitoring-yaml-demo.md
git commit -m "Add standalone Prometheus and Grafana YAML demo"
git push -u origin monitoring-yaml-demo
```

## 2. Check the prerequisites

```bash
kubectl config current-context
kubectl get nodes
kubectl get svc nginx-service -n production --show-labels
kubectl get svc nginx-service -n production -o jsonpath='{.spec.ports[*].name}{"\n"}'
kubectl get storageclass ebs-gp3
```

Expected service label includes `app=nginx`; port names include `metrics`. Use the intended EKS context before applying.

## 3. Apply the manifests

From the repository root:

```bash
kubectl apply -f kubernetes/prod/07-monitoring-yaml-demo/
kubectl get pods,pvc,svc -n monitoring-yaml -w
```

Wait for both Deployments to become ready, then check logs and Prometheus targets:

```bash
kubectl rollout status deployment/prometheus-yaml -n monitoring-yaml --timeout=5m
kubectl rollout status deployment/grafana-yaml -n monitoring-yaml --timeout=5m
kubectl logs deployment/prometheus-yaml -n monitoring-yaml
```

Forward Prometheus in one terminal and open `http://localhost:9090/targets`:

```bash
kubectl port-forward -n monitoring-yaml svc/prometheus-yaml 9090:9090
```

In Prometheus, run:

```promql
up{namespace="production",service="nginx-service"}
```

Three `1` series means the three exporter endpoints are being scraped. Then check:

```promql
nginx_connections_active{namespace="production",service="nginx-service"}
```

Forward Grafana in a second terminal and open `http://localhost:3000`:

```bash
kubectl port-forward -n monitoring-yaml svc/grafana-yaml 3000:3000
```

Grafana's initial login is `admin` / `admin`; change the password when prompted. The YAML provisions a Prometheus datasource and an `NGINX Metrics - YAML Demo` dashboard automatically.

## 4. What each YAML file teaches

| File | Purpose |
| --- | --- |
| `00-namespace.yaml` | Creates an isolated namespace for this demo. |
| `01-prometheus-rbac.yaml` | Gives Prometheus read-only discovery access to Services, EndpointSlices, and Pods in `production`. |
| `02-nginx-metrics-network-policy.yaml` | Allows only the demo namespace to reach the NGINX exporter port. |
| `03-prometheus-config.yaml` | Configures Kubernetes EndpointSlice discovery and Prometheus scrape/relabel rules. |
| `04-prometheus.yaml` | Creates Prometheus storage, Deployment, and ClusterIP Service. |
| `05-grafana-config.yaml` | Provisions the Prometheus datasource, dashboard provider, and dashboard JSON. |
| `06-grafana.yaml` | Creates Grafana storage, Deployment, and ClusterIP Service. |

## 5. Clean up the demo

This removes only the demo namespace and its resources, plus the separate additive policy in `production`. PVCs use the existing `ebs-gp3` StorageClass with `Delete` reclaim policy, so their dynamically provisioned EBS volumes should be removed after PVC deletion completes.

```bash
kubectl delete networkpolicy nginx-allow-yaml-monitoring-demo -n production --ignore-not-found
kubectl delete rolebinding prometheus-yaml-discovery -n production --ignore-not-found
kubectl delete role prometheus-yaml-discovery -n production --ignore-not-found
kubectl delete namespace monitoring-yaml --wait=true
kubectl get namespace monitoring-yaml
kubectl get networkpolicy nginx-allow-yaml-monitoring-demo -n production
kubectl get pv
```

The namespace and demo policy should be absent. If a PVC or PV remains terminating, inspect its events and finalizers before force-removing anything.

## Important scope note

This is a compact teaching setup, not feature-equivalent to `kube-prometheus-stack`. The Helm chart installs and wires many additional exporters, Kubernetes control-plane monitors, alerting rules, Alertmanager, and operator-managed resources. Keep the Terraform/Helm stack in `monitoring` as the production-style installation; use this branch to learn how the core Prometheus and Grafana pieces fit together through YAML.
