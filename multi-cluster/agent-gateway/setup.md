```
export SOLO_LICENSE_KEY=
```

```
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml --context=$CLUSTER1
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml --context=$CLUSTER2
```

```
helm upgrade -i --create-namespace --namespace gloo-system --kube-context=$CLUSTER1 \
--version 2.0.0-beta.3 gloo-gateway-crds oci://us-docker.pkg.dev/solo-public/gloo-gateway/charts/gloo-gateway-crds

helm upgrade -i --create-namespace --namespace gloo-system --kube-context=$CLUSTER2 \
--version 2.0.0-beta.3 gloo-gateway-crds oci://us-docker.pkg.dev/solo-public/gloo-gateway/charts/gloo-gateway-crds
```

```
helm install -n gloo-system agentgateway oci://us-docker.pkg.dev/solo-public/gloo-gateway/charts/gloo-gateway \
--kube-context=$CLUSTER1 \
--version 2.0.0-beta.3 \
--set-string licensing.glooGatewayLicenseKey=$SOLO_LICENSE_KEY \
-f - <<EOF
gloo:
  discovery:
    enabled: false
  gatewayProxies:
    gatewayProxy:
      disabled: true
  gateway:
    aiExtension:
      enabled: true
  agentGateway:
    enabled: true
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
helm install -n gloo-system agentgateway oci://us-docker.pkg.dev/solo-public/gloo-gateway/charts/gloo-gateway \
--kube-context=$CLUSTER2 \
--version 2.0.0-beta.3 \
--set-string licensing.glooGatewayLicenseKey=$SOLO_LICENSE_KEY \
-f - <<EOF
gloo:
  discovery:
    enabled: false
  gatewayProxies:
    gatewayProxy:
      disabled: true
  gateway:
    aiExtension:
      enabled: true
  agentGateway:
    enabled: true
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
kubectl get gatewayclass -n gloo-system --context=$CLUSTER1
kubectl get gatewayclass -n gloo-gateway --context=$CLUSTER2
```