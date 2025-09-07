```
export SOLO_LICENSE_KEY=
```

### CRDs for the Kubernetes Gateway API (needed for Waypoint/L7)
```
export release='v1.3.0'
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/$release/standard-install.yaml
```

### Gloo Operator
```
helm install gloo-operator oci://us-docker.pkg.dev/solo-public/gloo-operator-helm/gloo-operator \
--version 0.3.1 \
-n gloo-mesh \
--create-namespace \
--set manager.env.SOLO_ISTIO_LICENSE_KEY=${SOLO_LICENSE_KEY}
```

## Verify Operator
```
kubectl get pods -n gloo-mesh
```

### ServiceMeshController CRD
Automatically install Istio and set the data plane to be Ambient
```
kubectl apply -n gloo-mesh -f -<<EOF
apiVersion: operator.gloo.solo.io/v1
kind: ServiceMeshController
metadata:
  name: managed-istio
  labels:
    app.kubernetes.io/name: managed-istio
spec:
  dataplaneMode: Ambient
  installNamespace: istio-system
  version: 1.27.0
EOF
```

### Verify Istio Control and Data Plane
```
kubectl get pods -n istio-system
```
