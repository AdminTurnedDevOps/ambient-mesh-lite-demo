```
export SOLO_LICENSE_KEY=
```

## Install Kubernetes Gateway API
```
export RELEASE=v1.3.0

kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/$RELEASE/standard-install.yaml
```

## install GlooCTL
```
brew install glooctl
```

## Install Gloo Gateway WITH L7 Waypoint
```
glooctl install gateway enterprise \
--license-key $SOLO_LICENSE_KEY \
--version 1.20.0-rc1 \
--values - << EOF
gloo:
  gatewayProxies:
    gatewayProxy:
      disabled: true
  gloo:
    disableLeaderElection: true
    deployment:
      customEnv:
        - name: ENABLE_WAYPOINTS
          value: "true"
  kubeGateway:
    enabled: true
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
ambient:
  waypoint:
    enabled: true
EOF
```

## Install Gloo Gateway WITHOUT L7 Waypoint
```
glooctl install gateway enterprise \
--license-key $SOLO_LICENSE_KEY \
--version 1.20.0-rc1 \
--values - << EOF
gloo:
  gatewayProxies:
    gatewayProxy:
      disabled: true
  gloo:
    disableLeaderElection: true
  kubeGateway:
    enabled: true
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

## Ensure Gloo Gateway was installed properly
```
kubectl get pods -n gloo-system
```

## See the Gateway class that was created
```
kubectl get gatewayclass gloo-gateway
```

## IF YOU USED THE WAYPOINT INSTALL - see that the Gateway class was created

```
kubectl get gatewayclass gloo-waypoint -n gloo-system
```