### Env Variables

```
export SOLO_LICENSE_KEY=
```

```
export CLUSTER1=
export CLUSTER2=

export CLUSTER1_NAME=
export CLUSTER2_NAME=
```

```
export ISTIO_VERSION=1.26.4
export ISTIO_IMAGE=$ISTIO_VERSION-solo
```

```
### Get keys from the below link:
https://support.solo.io/hc/en-us/articles/4414409064596-Istio-images-built-by-Solo-io

export REPO_KEY=
```

```
export REPO=us-docker.pkg.dev/gloo-mesh/istio-$REPO_KEY
export HELM_REPO=us-docker.pkg.dev/gloo-mesh/istio-helm-$REPO_KEY
```

### Deploy Sample App
```
for context in $CLUSTER1 $CLUSTER2; do
  kubectl --context $context create namespace emojivoto
  kubectl --context $context -n emojivoto apply -k kubernetes-sample-apps/emojivoto-example/kustomize/
done
```

### Kubernetes Gateway API CRDs

```
for context in $CLUSTER1 $CLUSTER2; do
  kubectl apply --context $context -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
done
```

### Self-Signed Certs For Shared Root Trust (Comms Between Clusters)
```
for context in ${CLUSTER1} ${CLUSTER2}; do
  kubectl --context=${context} create ns istio-system || true
  kubectl --context=${context} create ns istio-gateways || true
done
kubectl --context=${CLUSTER1} create secret generic cacerts -n istio-system \
--from-file=./certs/cluster1/ca-cert.pem \
--from-file=./certs/cluster1/ca-key.pem \
--from-file=./certs/cluster1/root-cert.pem \
--from-file=./certs/cluster1/cert-chain.pem
kubectl --context=${CLUSTER2} create secret generic cacerts -n istio-system \
--from-file=./certs/cluster2/ca-cert.pem \
--from-file=./certs/cluster2/ca-key.pem \
--from-file=./certs/cluster2/root-cert.pem \
--from-file=./certs/cluster2/cert-chain.pem
```

### Istio CRDs and Control Plane (Istiod)
```
for context in $CLUSTER1 $CLUSTER2; do
  helm upgrade --install istio-base oci://$HELM_REPO/base \
  --namespace istio-system \
  --create-namespace \
  --kube-context $context \
  --version $ISTIO_IMAGE \
  -f - <<EOF
  defaultRevision: ""
  profile: ambient
EOF
done
```

```
helm upgrade --install istiod oci://$HELM_REPO/istiod \
--namespace istio-system \
--kube-context $CLUSTER1 \
--version $ISTIO_IMAGE \
-f - <<EOF
env:
  # Assigns IP addresses to multicluster services
  PILOT_ENABLE_IP_AUTOALLOCATE: "true"
  # Disable selecting workload entries for local service routing.
  # Required for Gloo VirtualDestinaton functionality.
  PILOT_ENABLE_K8S_SELECT_WORKLOAD_ENTRIES: "false"
  # Required when meshConfig.trustDomain is set
  PILOT_SKIP_VALIDATE_TRUST_DOMAIN: "true"
global:
  hub: $REPO
  multiCluster:
    clusterName: $CLUSTER1_NAME
  network: $CLUSTER1_NAME
  proxy:
    clusterDomain: cluster.local
  tag: $ISTIO_IMAGE
meshConfig:
  accessLogFile: /dev/stdout
  defaultConfig:
    proxyMetadata:
      ISTIO_META_DNS_AUTO_ALLOCATE: "true"
      ISTIO_META_DNS_CAPTURE: "true"
  enableTracing: true
  defaultConfig:
    tracing:
      sampling: 100
      zipkin:
        address: gloo-telemetry-collector.gloo-mesh.svc.cluster.local:9411
  trustDomain: "$CLUSTER1_NAME.local"
pilot:
  cni:
    namespace: istio-system
    enabled: true
platforms:
  peering:
    enabled: true
profile: ambient
license:
  value: $SOLO_LICENSE_KEY
EOF

helm upgrade --install istiod oci://$HELM_REPO/istiod \
--namespace istio-system \
--kube-context $CLUSTER2 \
--version $ISTIO_IMAGE \
-f - <<EOF
env:
  PILOT_ENABLE_IP_AUTOALLOCATE: "true"
  PILOT_ENABLE_K8S_SELECT_WORKLOAD_ENTRIES: "false"
  PILOT_SKIP_VALIDATE_TRUST_DOMAIN: "true"
global:
  hub: $REPO
  multiCluster:
    clusterName: $CLUSTER2_NAME
  network: $CLUSTER2_NAME
  proxy:
    clusterDomain: cluster.local
  tag: $ISTIO_IMAGE
meshConfig:
  accessLogFile: /dev/stdout
  defaultConfig:
    proxyMetadata:
      ISTIO_META_DNS_AUTO_ALLOCATE: "true"
      ISTIO_META_DNS_CAPTURE: "true"
  enableTracing: true
  defaultConfig:
    tracing:
      sampling: 100
      zipkin:
        address: gloo-telemetry-collector.gloo-mesh.svc.cluster.local:9411
  trustDomain: "$CLUSTER2_NAME.local"
pilot:
  cni:
    namespace: istio-system
    enabled: true
platforms:
  peering:
    enabled: true
profile: ambient
license:
  value: $SOLO_LICENSE_KEY
EOF
```

## Istio CNI
```
for context in $CLUSTER1 $CLUSTER2; do
  helm upgrade --install istio-cni oci://$HELM_REPO/cni \
  --namespace istio-system \
  --kube-context $context \
  --version $ISTIO_IMAGE \
  -f - <<EOF
  # Assigns IP addresses to multicluster services
  ambient:
    dnsCapture: true
  excludeNamespaces:
    - istio-system
    - kube-system
  global:
    hub: $REPO
    tag: $ISTIO_IMAGE
    platform: gke # Uncomment for GKE
  profile: ambient
  # Uncomment these two lines for GKE
  resourceQuotas: 
    enabled: true
EOF
done
```

## Install Ztunnel
```
helm upgrade --install ztunnel oci://$HELM_REPO/ztunnel \
--namespace istio-system \
--kube-context $CLUSTER1 \
--version $ISTIO_IMAGE \
-f - <<EOF
configValidation: true
enabled: true
env:
  L7_ENABLED: "true"
  # Required when a unique trust domain is set for each cluster
  SKIP_VALIDATE_TRUST_DOMAIN: "true"
l7Telemetry:
  distributedTracing:
    otlpEndpoint: "http://gloo-telemetry-collector.gloo-mesh:4317"
global:
  platform: gke # Uncomment for GKE
hub: $REPO
istioNamespace: istio-system
multiCluster:
  clusterName: $CLUSTER1_NAME
namespace: istio-system
profile: ambient
proxy:
  clusterDomain: cluster.local
tag: $ISTIO_IMAGE
terminationGracePeriodSeconds: 29
variant: distroless
EOF

helm upgrade --install ztunnel oci://$HELM_REPO/ztunnel \
--namespace istio-system \
--kube-context $CLUSTER2 \
--version $ISTIO_IMAGE \
-f - <<EOF
configValidation: true
enabled: true
env:
  L7_ENABLED: "true"
  # Required when a unique trust domain is set for each cluster
  SKIP_VALIDATE_TRUST_DOMAIN: "true"
l7Telemetry:
  distributedTracing:
    otlpEndpoint: "http://gloo-telemetry-collector.gloo-mesh:4317"
global:
  platform: gke # Uncomment for GKE
hub: $REPO
istioNamespace: istio-system
multiCluster:
  clusterName: $CLUSTER2_NAME
namespace: istio-system
profile: ambient
proxy:
  clusterDomain: cluster.local
tag: $ISTIO_IMAGE
terminationGracePeriodSeconds: 29
variant: distroless
EOF
```

## Deploy Gateways - ONLY IF YOU DO NOT USE EXPOSE
```
for context in $CLUSTER1 $CLUSTER2; do
  kubectl create namespace --context $context istio-gateways
done

kubectl apply --context $CLUSTER1 -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  labels:
    istio.io/expose-istiod: "15012"
    topology.istio.io/network: $CLUSTER1_NAME
  name: istio-eastwest
  namespace: istio-gateways
spec:
  gatewayClassName: istio-eastwest
  listeners:
  - name: cross-network
    port: 15008
    protocol: HBONE
    tls:
      mode: Passthrough
  - name: xds-tls
    port: 15012
    protocol: TLS
    tls:
      mode: Passthrough
EOF

kubectl apply --context $CLUSTER2 -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  labels:
    istio.io/expose-istiod: "15012"
    topology.istio.io/network: $CLUSTER2_NAME
  name: istio-eastwest
  namespace: istio-gateways
spec:
  gatewayClassName: istio-eastwest
  listeners:
  - name: cross-network
    port: 15008
    protocol: HBONE
    tls:
      mode: Passthrough
  - name: xds-tls
    port: 15012
    protocol: TLS
    tls:
      mode: Passthrough
EOF
```

## Label Clusters
Label clusters for the metadata that is needed to ensure the clusters can communicate. This is going to be the Namespace where the east/west gateways are.

```
kubectl label namespace istio-system topology.istio.io/network=$CLUSTER1_NAME --context=$CLUSTER1
kubectl label namespace istio-system topology.istio.io/network=$CLUSTER2_NAME --context=$CLUSTER2
```


```
kubectl annotate gateway istio-eastwest -n istio-gateways gateway.istio.io/service-account=istio-eastwest --context=$CLUSTER1
kubectl annotate gateway istio-eastwest -n istio-gateways gateway.istio.io/service-account=istio-eastwest --context=$CLUSTER2

kubectl annotate gateway istio-eastwest -n istio-gateways gateway.istio.io/trust-domain=$CLUSTER2 --context=$CLUSTER1
kubectl annotate gateway istio-eastwest -n istio-gateways gateway.istio.io/trust-domain=$CLUSTER1 --context=$CLUSTER2

kubectl label svc istio-eastwest -n istio-gateways istio=eastwestgateway --context=$CLUSTER1
kubectl label svc istio-eastwest -n istio-gateways istio=eastwestgateway --context=$CLUSTER2
```

```
kubectl get namespace istio-gateways -o jsonpath='{.metadata.annotations}'
```

## Peer Clusters
Please note that the `expose` command is not needed (which is why you only see the link command) as the Gateway configuration we did above does the same thing that the `expose` command does.

```
# The below istioctl implementation is specifically for 1.26.

OS=$(uname | tr '[:upper:]' '[:lower:]' | sed -E 's/darwin/osx/')
ARCH=$(uname -m | sed -E 's/aarch/arm/; s/x86_64/amd64/; s/armv7l/armv7/')
echo $OS
echo $ARCH

mkdir -p ~/.istioctl/bin
curl -sSL https://storage.googleapis.com/istio-binaries-$REPO_KEY/$ISTIO_IMAGE/istioctl-$ISTIO_IMAGE-$OS-$ARCH.tar.gz | tar xzf - -C ~/.istioctl/bin
chmod +x ~/.istioctl/bin/istioctl

export PATH=${HOME}/.istioctl/bin:${PATH}

istioctl --context=${CLUSTER1} multicluster expose -n istio-gateways
istioctl --context=${CLUSTER2} multicluster expose -n istio-gateways

istioctl multicluster link --contexts=$CLUSTER1,$CLUSTER2 -n istio-gateways
```

for context in ${CLUSTER1} ${CLUSTER2}; do
  kubectl get gateways -n istio-gateways --context ${context}
done

## For Multicluster Management Pane
```
meshctl install --profiles gloo-mesh-mgmt \
--set common.cluster=$CLUSTER1 \
--set licensing.glooMeshCoreLicenseKey=$SOLO_LICENSE_KEY
```