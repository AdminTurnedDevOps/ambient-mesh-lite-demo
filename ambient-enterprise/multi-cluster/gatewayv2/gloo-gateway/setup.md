export SOLO_LICENSE_KEY=
```

```
helm repo add glooe https://storage.googleapis.com/gloo-ee-helm
helm repo update
```

```
helm install -n gloo-system gloo glooe/gloo-ee --kube-context=$CLUSTER1 \
--create-namespace \
--version 1.19.8 \
--set-string license_key=$SOLO_LICENSE_KEY \
-f - <<EOF
gloo:
  discovery:
    enabled: false
  gatewayProxies:
    gatewayProxy:
      disabled: true
  kubeGateway:
    enabled: true
  gloo:
    disableLeaderElection: true
    deployment:
      customEnv:
        - name: ENABLE_WAYPOINTS
          value: "true"
        - name: GG_AMBIENT_MULTINETWORK
          value: "true"
gloo-fed:
  enabled: false
  glooFedApiserver:
    enable: false
grafana:
  defaultInstallationEnabled: false
observability:
  enabled: false
prometheus:
  enabled: false
EOF
```

```
helm install -n gloo-system gloo glooe/gloo-ee --kube-context=$CLUSTER2 \
--create-namespace \
--version 1.19.8 \
--set-string license_key=$SOLO_LICENSE_KEY \
-f - <<EOF
gloo:
  discovery:
    enabled: false
  gatewayProxies:
    gatewayProxy:
      disabled: true
  kubeGateway:
    enabled: true
  gloo:
    disableLeaderElection: true
    deployment:
      customEnv:
        - name: ENABLE_WAYPOINTS
          value: "true"
        - name: GG_AMBIENT_MULTINETWORK
          value: "true"
gloo-fed:
  enabled: false
  glooFedApiserver:
    enable: false
grafana:
  defaultInstallationEnabled: false
observability:
  enabled: false
prometheus:
  enabled: false
EOF
```

```
kubectl get pods -n gloo-system --context=$CLUSTER1
kubectl get pods -n gloo-system --context=$CLUSTER2
```

```
kubectl get gatewayclass gloo-gateway --context=$CLUSTER1
kubectl get gatewayclass gloo-gateway --context=$CLUSTER2
```