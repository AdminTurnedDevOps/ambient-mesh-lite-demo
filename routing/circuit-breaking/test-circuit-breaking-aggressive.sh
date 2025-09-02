#!/bin/bash

set -e

NAMESPACE="emojivoto"
SERVICE="web-svc"
PORT="8080"

echo "Aggressive Circuit Breaking Test for Web Service"
echo "==============================================="

# Port forward
kubectl port-forward -n $NAMESPACE svc/$SERVICE $PORT:80 &
PORT_FORWARD_PID=$!
sleep 3

cleanup() {
    echo "Cleaning up port forward..."
    kill $PORT_FORWARD_PID >/dev/null 2>&1 || true
    wait $PORT_FORWARD_PID >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "1. Testing baseline requests..."
for i in {1..3}; do
    response=$(curl -s -w "%{http_code}" -o /dev/null "http://localhost:$PORT/" || echo "000")
    echo "   Baseline $i: HTTP $response"
done

echo "2. Aggressive load test (200 concurrent requests in 5 waves)..."
for wave in {1..5}; do
    echo "   Wave $wave: Sending 40 concurrent requests..."
    for i in {1..40}; do
        (
            response=$(curl -s -w "%{http_code}" -m 1 -o /dev/null "http://localhost:$PORT/" 2>/dev/null || echo "FAIL")
            echo "Wave $wave Request $i: $response"
        ) &
    done
    wait
    sleep 1
done

echo "3. Testing immediate post-load requests..."
for i in {1..5}; do
    response=$(curl -s -w "%{http_code}" -o /dev/null "http://localhost:$PORT/" || echo "000")
    echo "   Post-load $i: HTTP $response"
    sleep 1
done

echo "4. Waiting for circuit breaker recovery (35s)..."
sleep 35

echo "5. Testing recovery requests..."
for i in {1..5}; do
    response=$(curl -s -w "%{http_code}" -o /dev/null "http://localhost:$PORT/" || echo "000")
    echo "   Recovery $i: HTTP $response"
    sleep 1
done

echo "==============================================="
echo "Test complete! Look for:"
echo "- HTTP 503 or connection failures during load test"
echo "- Successful 200 responses after recovery period"