```
helm install istio-base istio/base -n istio-system --create-namespace --wait
```

```
kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || \
  kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml
```

```
helm install istiod istio/istiod --namespace istio-system --set profile=ambient --wait
```

```
helm install istio-cni istio/cni -n istio-system --set profile=ambient
```

```
helm install ztunnel istio/ztunnel -n istio-system
```