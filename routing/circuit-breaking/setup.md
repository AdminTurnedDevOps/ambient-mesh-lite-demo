Circuit Breaking temporarily stops requests to a failing or overloaded service, which helps in preventing cascading failures. It helps in reducing infinite loops.

```
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: microservices-frontend
  namespace: microapp
spec:
  # The host would be either your backend service or
  # the `name` within your `BackendRef` for multi-cluster routing
  host: frontend.microapp.mesh.internal
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        maxRequestsPerConnection: 10
    outlierDetection:
      consecutiveErrors: 3
      interval: 30s
      baseEjectionTime: 30s
EOF
```