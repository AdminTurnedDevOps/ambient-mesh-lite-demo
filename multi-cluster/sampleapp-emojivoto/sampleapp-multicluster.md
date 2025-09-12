```
export CLUSTER1=
export CLUSTER2=

export CLUSTER1_NAME=
export CLUSTER2_NAME=
```

```
git clone https://github.com/digitalocean/kubernetes-sample-apps.git
```

```
### Deploy Sample App
```
kubectl create namespace emojivoto --context=$CLUSTER1
kubectl create namespace emojivoto --context=$CLUSTER2
kubectl -n emojivoto apply -k kubernetes-sample-apps/emojivoto-example/kustomize/ --context=$CLUSTER1
kubectl -n emojivoto apply -k kubernetes-sample-apps/emojivoto-example/kustomize/ --context=$CLUSTER2
```

```
kubectl get pods -n emojivoto
```

Label Namespaces for Ambient Mode.
```
kubectl label namespace emojivoto istio.io/dataplane-mode=ambient --context=$CLUSTER1
kubectl label namespace emojivoto istio.io/dataplane-mode=ambient --context=$CLUSTER2
```

Make services available across clusters link 
```
kubectl --context $CLUSTER1 -n emojivoto label service web-svc solo.io/service-scope=global --overwrite
kubectl --context $CLUSTER2 -n emojivoto label service web-svc solo.io/service-scope=global --overwrite

kubectl --context $CLUSTER1 -n emojivoto annotate service web-svc networking.istio.io/traffic-distribution=Any --overwrite
kubectl --context $CLUSTER2 -n emojivoto annotate service web-svc networking.istio.io/traffic-distribution=Any --overwrite
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
  name: emoji-web-gateway
  namespace: emojivoto
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
  name: websvc
  namespace: emojivoto
spec:
  parentRefs:
  - name: emoji-web-gateway
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - kind: Hostname
      group: networking.istio.io
      name: web-svc.emojivoto.mesh.internal
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
  gatewayClassName: gloo-gateway
  listeners:
  - name: mesh
    port: 15008 
    protocol: HBONE
EOF
```