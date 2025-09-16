Weights allow you to specify how much traffic you want to go to each version of the application. For example, from a canary perspective, you may want 70% of the traffic going to v1 of the application and 30% going to V2.

```
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: frontend-weights
spec:
  parentRefs:
  - name: frontend-gateway
  rules:
  - backendRefs:
    - name: frontend-v1
      port: 80
      weight: 70
    - name: frontend-v2  
      port: 80
      weight: 30
EOF
```