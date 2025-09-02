#!/bin/bash

set -e

NAMESPACE="emojivoto"
SERVICE="web-svc"
PORT="8080"

echo "Testing Circuit Breaking for Emojivoto Service"
echo "=============================================="

# Check if service exists
echo "1. Checking if emoji-svc exists..."
kubectl get svc $SERVICE -n $NAMESPACE >/dev/null 2>&1 || {
    echo "Error: Service $SERVICE not found in namespace $NAMESPACE"
    exit 1
}

# Get service port
SVC_PORT=$(kubectl get svc $SERVICE -n $NAMESPACE -o jsonpath='{.spec.ports[0].port}')
echo "   Service found on port: $SVC_PORT"

# Port forward to access the service
echo "2. Setting up port forward..."
kubectl port-forward -n $NAMESPACE svc/$SERVICE $PORT:$SVC_PORT &
PORT_FORWARD_PID=$!
sleep 3

# Function to cleanup
cleanup() {
    echo "Cleaning up port forward..."
    kill $PORT_FORWARD_PID >/dev/null 2>&1 || true
    wait $PORT_FORWARD_PID >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Test 1: Normal requests
echo "3. Testing normal requests..."
for i in {1..5}; do
    response=$(curl -s -w "%{http_code}" -o /dev/null "http://localhost:$PORT/" || echo "000")
    echo "   Request $i: HTTP $response"
    sleep 0.5
done

# Test 2: Load test to trigger circuit breaking
echo "4. Load testing to trigger circuit breaker..."
echo "   Sending 50 concurrent requests..."

# Create multiple background processes to overwhelm the service
for i in {1..50}; do
    (
        response=$(curl -s -w "%{http_code}" -m 2 -o /dev/null "http://localhost:$PORT/api/list" 2>/dev/null || echo "000")
        echo "Concurrent request: HTTP $response"
    ) &
done

# Wait for all background jobs
wait

echo "5. Checking circuit breaker status..."
echo "   Waiting 5 seconds for metrics to update..."
sleep 5

# Test 3: Verify circuit breaker recovery
echo "6. Testing circuit breaker recovery..."
echo "   Waiting for ejection time (30s)..."
sleep 35

echo "7. Testing requests after recovery window..."
for i in {1..5}; do
    response=$(curl -s -w "%{http_code}" -o /dev/null "http://localhost:$PORT/" || echo "000")
    echo "   Recovery request $i: HTTP $response"
    sleep 1
done

echo "=============================================="
echo "Circuit Breaking Test Complete!"
echo ""
echo "Expected behavior:"
echo "- Normal requests should return 200"
echo "- Load test should trigger some 503/connection errors"
echo "- Recovery requests should return 200 after ejection time"
echo ""
echo "Check Istio metrics for detailed circuit breaker stats:"
echo "kubectl exec -n istio-system deployment/istiod -- pilot-discovery request GET /stats/prometheus | grep circuit"