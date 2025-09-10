```
git clone https://github.com/digitalocean/kubernetes-sample-apps.git
```

```
kubectl create ns emojivoto
```

```
kubectl label ns emojivoto istio.io/dataplane-mode=ambient
```

```
cd kubernetes-sample-apps/emojivoto-example
```

```
kubectl apply -k kustomize/
```

```
kubectl get pods -n emojivoto
```

```
kubectl label namespace emojivoto istio.io/usewaypoint=auto
```

for context in ${CLUSTER1} ${CLUSTER2}; do
  kubectl --context ${context}  -n emojivoto label service web-svc solo.io/service-scope=global
  kubectl --context ${context}  -n emojivoto annotate service web-svc networking.istio.io/traffic-distribution=Any
done```

```

```
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: emoji-waypoint
  namespace: emojivoto
  annotations:
    waypoint.istio.io/for: service
spec:
  gatewayClassName: gloo-gateway
  listeners:
  - name: mesh
    port: 15008 
    protocol: HBONE
EOF
```

```
apiVersion: v1
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: emoji-web-gateway
spec:
  gatewayClassName: gloo-gateway
  listeners:
  - name: web
    port: 80
    protocol: HTTP
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: web-svc
spec:
  parentRefs:
  - name: emoji-web-gateway
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: web-svc
      port: 8080
```