
### Deploy Sample App
```
git clone https://github.com/digitalocean/kubernetes-sample-apps/tree/master/emojivoto-example
```

```
kubectl create ns emojivoto
```

```
kubectl -n emojivoto apply -k sampleapp-emojivoto/emojivoto-example/kustomize/
```

```
kubectl get pods -n emojivoto
```

### Label Namespaces for Ambient Mode.
```
kubectl label namespace emojivoto istio.io/dataplane-mode=ambient
```

### Expose App

```
kubectl apply --context=$CLUSTER1 -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: websvc-gateway
  namespace: emojivoto
spec:
  gatewayClassName: istio
  listeners:
  - name: web-svc
    port: 80
    protocol: HTTP
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: websvc
  namespace: emojivoto
spec:
  parentRefs:
  - name: websvc-gateway
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
      - name: web-svc
        port: 80
EOF
```