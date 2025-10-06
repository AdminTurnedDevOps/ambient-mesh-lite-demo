```
export CLUSTER1=
export CLUSTER2=

export CLUSTER1_NAME=
export CLUSTER2_NAME=
```

### Deploy Sample App
```
kubectl create ns microapp --context=$CLUSTER1
kubectl create ns microapp --context=$CLUSTER2

kubectl apply -f multi-cluster/sampleapp-microdemo/microservices-demo/release/kubernetes-manifests.yaml -n microapp --context=$CLUSTER1
kubectl apply -f multi-cluster/sampleapp-microdemo/microservices-demo/release/kubernetes-manifests.yaml -n microapp --context=$CLUSTER2
```

```
kubectl get pods -n microapp
```

### Label Namespaces for Ambient Mode.
```
kubectl label namespace microapp istio.io/dataplane-mode=ambient --context=$CLUSTER1
kubectl label namespace microapp istio.io/dataplane-mode=ambient --context=$CLUSTER2
```

kubectl label namespace gloo-system istio.io/dataplane-mode=ambient --context=$CLUSTER1
kubectl label namespace gloo-system istio.io/dataplane-mode=ambient --context=$CLUSTER2

### Make services available across clusters link 
```
kubectl --context $CLUSTER1 -n microapp label service frontend solo.io/service-scope=global --overwrite
kubectl --context $CLUSTER2 -n microapp label service frontend solo.io/service-scope=global --overwrite
```

```
for context in $CLUSTER1 $CLUSTER2; do
  echo "Service entries and workload entries for cluster $context:"
  echo ""
  kubectl get serviceentry --context $context -n istio-system
  kubectl get workloadentry --context $context -n istio-system
  echo ""
done
```

```
kubectl apply --context=$CLUSTER1 -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: frontend-gateway
  namespace: microapp
spec:
  gatewayClassName: istio
  listeners:
  - name: frontend
    port: 80
    protocol: HTTP
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: frontend
  namespace: microapp
spec:
  parentRefs:
  - name: frontend-gateway
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - kind: Hostname
      group: networking.istio.io
      name: frontend.microapp.mesh.internal
      port: 80
EOF
```

If you'd like a Waypoint:
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
  gatewayClassName: istio
  listeners:
  - name: mesh
    port: 15008 
    protocol: HBONE
EOF
```