#!/bin/bash

set -e

echo "Circuit Breaking Test Using Fortio: https://github.com/fortio/fortio"
echo "===================================================="

NAMESPACE="emojivoto"
SERVICE="web-svc"

# Deploy fortio if not exists
echo "1. Setting up fortio load testing client..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: fortio
  namespace: $NAMESPACE
  labels:
    app: fortio
    service: fortio
spec:
  ports:
  - port: 8080
    name: http
  selector:
    app: fortio
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fortio-deploy
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: fortio
  template:
    metadata:
      labels:
        app: fortio
    spec:
      containers:
      - name: fortio
        image: fortio/fortio:latest_release
        ports:
        - containerPort: 8080
          name: http-fortio
        - containerPort: 8079
          name: grpc-ping
        - containerPort: 8078
          name: echo-server
EOF

echo "2. Waiting for fortio to be ready..."
kubectl wait --for=condition=available --timeout=60s deployment/fortio-deploy -n $NAMESPACE

# Get fortio pod name
FORTIO_POD=$(kubectl get pod -n $NAMESPACE -l app=fortio -o jsonpath='{.items[0].metadata.name}')
echo "   Fortio pod: $FORTIO_POD"

echo "3. Testing baseline with 1 connection (should work)..."
kubectl exec "$FORTIO_POD" -n $NAMESPACE -c fortio -- /usr/bin/fortio load -c 1 -qps 0 -n 10 -loglevel Warning http://$SERVICE/

echo "4. Testing with 2 connections (may start seeing some failures)..."
kubectl exec "$FORTIO_POD" -n $NAMESPACE -c fortio -- /usr/bin/fortio load -c 2 -qps 0 -n 20 -loglevel Warning http://$SERVICE/

echo "5. Testing with 5 connections (should trigger circuit breaker)..."
kubectl exec "$FORTIO_POD" -n $NAMESPACE -c fortio -- /usr/bin/fortio load -c 5 -qps 0 -n 30 -loglevel Warning http://$SERVICE/

echo "6. Testing with 10 connections (heavy circuit breaking)..."
kubectl exec "$FORTIO_POD" -n $NAMESPACE -c fortio -- /usr/bin/fortio load -c 10 -qps 0 -n 50 -loglevel Warning http://$SERVICE/

echo "===================================================="
echo "✅ Circuit Breaking Test Complete!"
echo ""
echo "Expected results:"
echo "- 1 connection: ~100% success (200 codes)"
echo "- 2+ connections: Mix of 200 and 503 codes"
echo "- Higher connections: More 503 codes due to:"
echo "  • maxConnections: 100"
echo "  • http1MaxPendingRequests: 50" 
echo "  • maxRequestsPerConnection: 10"
echo ""
echo "Check waypoint logs:"
echo "kubectl logs -n $NAMESPACE deployment/gloo-proxy-emoji-waypoint"