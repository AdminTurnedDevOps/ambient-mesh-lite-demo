```
export GLOO_GATEWAY_LICENSE_KEY=

export AGENTGATEWAY_LICENSE_KEY=
```

```
export CLUSTER1=
export CLUSTER2=

export CLUSTER1_NAME=
export CLUSTER2_NAME=
```

```
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml --context=$CLUSTER1

kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml --context=$CLUSTER2
```

```
helm upgrade -i gloo-gateway-crds oci://us-docker.pkg.dev/solo-public/gloo-gateway/charts/gloo-gateway-crds --kube-context=$CLUSTER1 \
--create-namespace \
--namespace gloo-system \
--version 2.0.0-rc.1

helm upgrade -i gloo-gateway-crds oci://us-docker.pkg.dev/solo-public/gloo-gateway/charts/gloo-gateway-crds --kube-context=$CLUSTER2 \
--create-namespace \
--namespace gloo-system \
--version 2.0.0-rc.1
```

```
helm upgrade -i gloo-gateway oci://us-docker.pkg.dev/solo-public/gloo-gateway/charts/gloo-gateway --kube-context=$CLUSTER1 \
-n gloo-system \
--version 2.0.0-rc.1 \
--set agentgateway.enabled=true \
--set licensing.glooGatewayLicenseKey=$GLOO_GATEWAY_LICENSE_KEY \
--set licensing.agentgatewayLicenseKey=$AGENTGATEWAY_LICENSE_KEY

helm upgrade -i gloo-gateway oci://us-docker.pkg.dev/solo-public/gloo-gateway/charts/gloo-gateway --kube-context=$CLUSTER2 \
-n gloo-system \
--version 2.0.0-rc.1 \
--set agentgateway.enabled=true \
--set licensing.glooGatewayLicenseKey=$GLOO_GATEWAY_LICENSE_KEY \
--set licensing.agentgatewayLicenseKey=$AGENTGATEWAY_LICENSE_KEY
```

```
kubectl get pods -n gloo-system --context=$CLUSTER1
kubectl get pods -n gloo-system --context=$CLUSTER2
```

```
kubectl get gatewayclass -n gloo-system --context=$CLUSTER1
kubectl get gatewayclass -n gloo-system --context=$CLUSTER2
```