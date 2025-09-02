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
kubectl exec "$FORTIO_POD" -n $NAMESPACE -c fortio -- /usr/bin/fortio load -c 1 -qps 0 -n 5 -loglevel Warning http://$SERVICE/

echo "4. Testing maxRequestsPerConnection limit (10 requests per connection)..."
kubectl exec "$FORTIO_POD" -n $NAMESPACE -c fortio -- /usr/bin/fortio load -c 1 -qps 0 -n 15 -loglevel Warning http://$SERVICE/

echo "5. Testing http1MaxPendingRequests limit (50 pending requests)..."
kubectl exec "$FORTIO_POD" -n $NAMESPACE -c fortio -- /usr/bin/fortio load -c 5 -qps 0 -n 100 -loglevel Warning http://$SERVICE/

echo "6. Testing maxConnections limit (100 connections)..."
kubectl exec "$FORTIO_POD" -n $NAMESPACE -c fortio -- /usr/bin/fortio load -c 150 -qps 0 -n 300 -loglevel Warning http://$SERVICE/

echo "7. Testing outlier detection (consecutive errors)..."
echo "   Generating requests to trigger 3+ consecutive errors..."
for i in {1..5}; do
  echo "   Batch $i: Sending requests that may trigger outlier detection..."
  kubectl exec "$FORTIO_POD" -n $NAMESPACE -c fortio -- /usr/bin/fortio load -c 10 -qps 0 -n 20 -loglevel Warning http://$SERVICE/invalid-path || true
  echo "   Waiting 5s before next batch..."
  sleep 5
done

echo "8. Testing after outlier detection (should see some hosts ejected)..."
kubectl exec "$FORTIO_POD" -n $NAMESPACE -c fortio -- /usr/bin/fortio load -c 5 -qps 0 -n 25 -loglevel Warning http://$SERVICE/

echo "===================================================="
echo "✅ Circuit Breaking Test Complete!"
echo ""
echo "Expected results:"
echo "- Test 3 (baseline): ~100% success (200 codes)"
echo "- Test 4 (maxRequestsPerConnection): Some 503 codes after 10 requests per connection"
echo "- Test 5 (http1MaxPendingRequests): 503 codes when >50 requests are pending"
echo "- Test 6 (maxConnections): 503 codes when >100 connections attempted"
echo "- Test 7 (outlier detection): 404 codes from invalid paths"
echo "- Test 8 (post-outlier): Reduced success rate due to ejected hosts"
echo ""
echo "Configuration being tested:"
echo "  • maxConnections: 100"
echo "  • http1MaxPendingRequests: 50"
echo "  • maxRequestsPerConnection: 10"
echo "  • consecutiveErrors: 3 (outlier detection)"
echo "  • baseEjectionTime: 30s"
echo ""
echo "Check waypoint logs:"
echo "kubectl logs -n $NAMESPACE deployment/gloo-proxy-emoji-waypoint"