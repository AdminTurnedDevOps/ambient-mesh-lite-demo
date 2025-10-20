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
export ISTIO_VERSION=1.27.2
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

### Kubernetes Gateway API CRDs

```
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml --context=$CLUSTER1
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml --context=$CLUSTER2
```

### Istioctl Install
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

## Label Clusters
Label clusters for the metadata that is needed to ensure the clusters can communicate. The ambient control plane uses this label internally to group pods that exist in the same L3 network.

```
kubectl label namespace istio-system --context ${CLUSTER1} topology.istio.io/network=${CLUSTER1_NAME}
kubectl label namespace istio-system --context ${CLUSTER2} topology.istio.io/network=${CLUSTER2_NAME}
```

## Peer Clusters
Please note that the `expose` command is not needed (which is why you only see the link command) as the Gateway configuration we did above does the same thing that the `expose` command does.

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

## For Multicluster Management Pane
```
meshctl install --profiles gloo-mesh-mgmt \
--kubecontext $CLUSTER1 \
--set common.cluster=$CLUSTER1_NAME \
--set licensing.glooMeshCoreLicenseKey=$SOLO_LICENSE_KEY
```

## Register

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

## UI

```
kubectl port-forward svc/gloo-mesh-ui -n gloo-mesh 8080:8090
```