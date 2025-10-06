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