## Kube-Prometheus

```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
```

```
helm repo update
```

```
helm install kube-prometheus -n monitoring prometheus-community/kube-prometheus-stack --create-namespace
```

```
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: istiod
  namespace: monitoring
  labels:
    release: kube-prometheus  # Required for Prometheus to discover this ServiceMonitor
spec:
  selector:
    matchLabels:
      app: istiod
  namespaceSelector:
    matchNames:
      - istio-system
  endpoints:
  - port: http-monitoring
    interval: 30s
    path: /metrics
EOF
```

```
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: ztunnel
  namespace: monitoring
  labels:
    release: kube-prometheus  # Required for Prometheus to discover this PodMonitor
spec:
  selector:
    matchLabels:
      app: ztunnel
  namespaceSelector:
    matchNames:
      - istio-system
  podMetricsEndpoints:
  - port: ztunnel-stats
    interval: 30s
    path: /stats/prometheus
EOF
```

```
kubectl --namespace monitoring port-forward svc/kube-prometheus-kube-prome-prometheus 9090
```

```
kubectl --namespace monitoring port-forward svc/kube-prometheus-grafana 3000:80
```

To log into Grafana:
1. Username: admin
2. Password: prom-operator

Add Istiod and Ztunnel dashboards via the import button.
- For Istiod (the ID): 7645
- For Ztunnel (the ID): 21306

## Kiali Installation

Add Kiali Helm repository:
```
helm repo add kiali https://kiali.org/helm-charts
helm repo update
```

Install Kiali with Prometheus integration:
```
helm install kiali-server kiali/kiali-server \
  -n istio-system \
  --set auth.strategy="anonymous" \
  --set external_services.prometheus.url="http://kube-prometheus-kube-prome-prometheus.monitoring.svc.cluster.local:9090"
```

Port-forward to access Kiali dashboard:
```
kubectl port-forward -n istio-system svc/kiali 20001:20001
```

Access at: http://localhost:20001