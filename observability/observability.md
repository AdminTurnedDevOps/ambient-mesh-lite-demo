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