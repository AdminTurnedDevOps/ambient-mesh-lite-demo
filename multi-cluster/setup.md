The purpose of this demo is to show a few different methods/scenarios for how you'd set up Gloo Mesh in Ambient Mode.

It contains:

- Kubernetes Objects, which is one method for setting everything up if you don't use the Gloo Mesh Operator.
- Istioctl for peering clusters (you can also use Helm for this).
- Helm charts for installing Istio.
- Meshctl for deploying the management pane and registering a worker cluster.

You could use the Gloo Mesh Operator or Helm for the entire configuration, but this demo shows the "best of all worlds" so you can get a feel for various scenarios.

### Env Variables

The first step is to set environment variables. These will be needed for:
- Your Solo (Gloo Mesh) licnse key
- Cluster contexts and names
- Version of Istio
- Container image keys

```
export SOLO_LICENSE_KEY=
```

Set the Kube Context and the cluster name

```
export CLUSTER1=
export CLUSTER2=

export CLUSTER1_NAME=
export CLUSTER2_NAME=
```

```
#export ISTIO_VERSION=1.27.0

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

To test out the multi-cluster Gloo Mesh deployment after its up and running for things like routing, retries, timeouts, circuit breaking, and gateways, you'll need an app to test.

```
for context in $CLUSTER1 $CLUSTER2; do
  kubectl --context $context create namespace emojivoto
  kubectl --context $context -n emojivoto apply -k kubernetes-sample-apps/emojivoto-example/kustomize/
done
```

### Kubernetes Gateway API CRDs

The Kubernetes Gateway API CRDs are used for Gateway API objects as they do not come by default on Kubernetes.

```
for context in $CLUSTER1 $CLUSTER2; do
  kubectl apply --context $context -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
done
```

### Istioctl Install

This section will install the Istioctl, which you'll use for peering clusters.

```
OS=$(uname | tr '[:upper:]' '[:lower:]' | sed -E 's/darwin/osx/')
ARCH=$(uname -m | sed -E 's/aarch/arm/; s/x86_64/amd64/; s/armv7l/armv7/')
echo $OS
echo $ARCH

mkdir -p ~/.istioctl/bin
curl -sSL https://storage.googleapis.com/istio-binaries-$REPO_KEY/$ISTIO_IMAGE/istioctl-$ISTIO_IMAGE-$OS-$ARCH.tar.gz | tar xzf - -C ~/.istioctl/bin
chmod +x ~/.istioctl/bin/istioctl

export PATH=${HOME}/.istioctl/bin:${PATH}
```

### Self-Signed Certs For Shared Root Trust (Comms Between Clusters)

For clusters to be able to securely communicate with each other (e.g - a management cluster to a worker cluster), certs need to be issued. In production, you'd do this through an authorized CA or a CA of your choosing like `cert-manager`.

```
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${ISTIO_VERSION} sh -
cd istio-${ISTIO_VERSION}

mkdir -p certs
pushd certs
make -f ../tools/certs/Makefile.selfsigned.mk root-ca

function create_cacerts_secret() {
  context=${1:?context}
  cluster=${2:?cluster}
  make -f ../tools/certs/Makefile.selfsigned.mk ${cluster}-cacerts
  kubectl --context=${context} create ns istio-system || true
  kubectl --context=${context} create secret generic cacerts -n istio-system \
    --from-file=${cluster}/ca-cert.pem \
    --from-file=${cluster}/ca-key.pem \
    --from-file=${cluster}/root-cert.pem \
    --from-file=${cluster}/cert-chain.pem
}

create_cacerts_secret ${CLUSTER1} ${CLUSTER1_NAME}
create_cacerts_secret ${CLUSTER2} ${CLUSTER2_NAME}

cd ../..
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

With Ambient Mesh, the Istio CNI is used to redirect all incoming and outgoing Pod traffic to Ztunnel (which is deployed as a DaemonSet).

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

Ztunnel (outside of the Istio CNI providing the traffic management for incoming/outgoing requests) provides everything at the Layer 4 level. A good example of what happens at L4 is mTLS.

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

### Label Clusters
Label clusters for the metadata that is needed to ensure the clusters can communicate.

```
kubectl label namespace istio-system --context ${CLUSTER1} topology.istio.io/network=${CLUSTER1_NAME}
kubectl label namespace istio-system --context ${CLUSTER2} topology.istio.io/network=${CLUSTER2_NAME}
```

### Deploy Gateways

PLEASE SKIP if you will be using the following step, which is peering the clusters with `istioctl multicluster expose`. The `expose` command and the Gateway objects are doing the same thing (the `expose` command creates the Gateways)

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

## Peer Clusters

```
kubectl create namespace istio-eastwest --context=$CLUSTER1
kubectl create namespace istio-eastwest --context=$CLUSTER2

istioctl --context=${CLUSTER1} multicluster expose -n istio-eastwest
istioctl --context=${CLUSTER2} multicluster expose -n istio-eastwest

SIDENOTE: You may have to wait a minute or two for the next step as the cloud LBs need to be provisioned first.
istioctl multicluster link --namespace istio-eastwest --contexts=$CLUSTER1,$CLUSTER2
```

for context in ${CLUSTER1} ${CLUSTER2}; do
  kubectl get gateways -n istio-eastwest --context ${context}
done

### For Multicluster Management Pane
```
meshctl install --profiles gloo-mesh-mgmt \
--kubecontext $CLUSTER1 \
--set common.cluster=$CLUSTER1_NAME \
--set licensing.glooMeshCoreLicenseKey=$SOLO_LICENSE_KEY
```

### Register

When you set up a multi-cluster environment, you'll have a "management cluster" that runs the pane/UI and "worker clusters" that are running your workloads. This step shows you how to register a cluster.

```
export TELEMETRY_GATEWAY_IP=$(kubectl get svc -n gloo-mesh gloo-telemetry-gateway --context $CLUSTER1 -o jsonpath="{.status.loadBalancer.ingress[0]['hostname','ip']}")
export TELEMETRY_GATEWAY_PORT=$(kubectl get svc -n gloo-mesh gloo-telemetry-gateway --context $CLUSTER1 -o jsonpath='{.spec.ports[?(@.name=="otlp")].port}')
export TELEMETRY_GATEWAY_ADDRESS=${TELEMETRY_GATEWAY_IP}:${TELEMETRY_GATEWAY_PORT}
echo $TELEMETRY_GATEWAY_ADDRESS
```

```
meshctl cluster register $CLUSTER2_NAME \
  --kubecontext $CLUSTER1 \
  --profiles gloo-mesh-agent \
  --remote-context $CLUSTER2 \
  --telemetry-server-address $TELEMETRY_GATEWAY_ADDRESS
```