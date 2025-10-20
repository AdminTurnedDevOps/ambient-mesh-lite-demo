## OSS Ambient

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

## kgateway (OSS Gateway)

```
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml
```

```
helm upgrade -i --create-namespace --namespace kgateway-system --version v2.1.0 kgateway-crds oci://cr.kgateway.dev/kgateway-dev/charts/kgateway-crds 
```

```
helm upgrade -i -n kgateway-system kgateway oci://cr.kgateway.dev/kgateway-dev/charts/kgateway \
--version v2.1.0
```

```
kubectl get pods -n kgateway-system
```

```
kubectl get gatewayclass
```