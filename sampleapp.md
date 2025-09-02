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

Waypoint for Emojivoto
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