```
export SOLO_LICENSE_KEY=
```

```
export CLUSTER_NAME=

meshctl install --profiles gloo-mesh-single-cluster \
--set common.cluster=$CLUSTER_NAME \
--set licensing.glooMeshCoreLicenseKey=$SOLO_LICENSE_KEY
```

```
meshctl check
```

```
meshctl dashboard
```