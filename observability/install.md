
```
kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || \
  kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml
```

```
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update istio
```

```
helm upgrade --install istio-base istio/base -n istio-system --create-namespace
```

```
helm upgrade --install istiod istio/istiod --namespace istio-system --set profile=ambient
```

```
helm upgrade --install istio-cni istio/cni -n istio-system --set profile=ambient
```

```
helm upgrade --install ztunnel istio/ztunnel -n istio-system
```