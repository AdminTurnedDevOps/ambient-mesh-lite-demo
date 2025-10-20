1. Install Kubernetes Gateway API CRDs
```
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml
```

2. Deploy your app
```
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: microapp
  namespace: argocd # Or your designated Argo CD namespace
spec:
  project: default
  source:
    repoURL: https://github.com/GoogleCloudPlatform/microservices-demo.git
    targetRevision: main
    path: release/
    directory:
      include: 'kubernetes-manifests.yaml'
  destination:
    server: https://kubernetes.default.svc # Or the API server URL of your target cluster
    namespace: microapp
  syncPolicy:
    automated:
      selfHeal: true # Automatically sync differences between Git and cluster state
    syncOptions:
      - CreateNamespace=true
EOF
```

3. Label the Namesapce to enroll your app into Ambient Mesh
```
kubectl label namespace microapp istio.io/dataplane-mode=ambient
```

You should now see your Istio Ambient Mesh and App deployed.

![](images/apps.png)

If you want to see the Ui/frontend of the app, create a Gateway and HTTPRoute. This is not mandatory for the lab
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
      - name: frontend
        port: 80
EOF
```

You should be able to look at Ztunnel Pod logs to see that the microapp is enrolled into Ambient Mesh.

```
kubectl logs ztunnel-pod-name -n istio-system
```

```
2025-10-20T12:55:32.030893Z     info    xds::client:xds{id=1}   received response       type_url="type.googleapis.com/istio.workload.Address" size=1 removes=0
2025-10-20T12:55:34.416874Z     info    access  connection complete     src.addr=10.28.3.17:50170 src.workload="loadgenerator-56674fd696-c2w7w" src.namespace="microapp" src.identity="spiffe://cluster.local/ns/microapp/sa/loadgenerator" dst.addr=10.28.4.18:15008 dst.hbone_addr=10.28.4.18:8080 dst.service="frontend.microapp.svc.cluster.local" dst.workload="frontend-76dbbddfc5-cdmwx" dst.namespace="microapp" dst.identity="spiffe://cluster.local/ns/microapp/sa/frontend" direction="outbound" bytes_sent=74 bytes_recv=11117 duration="1296ms"
```