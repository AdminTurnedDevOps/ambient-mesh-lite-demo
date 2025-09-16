Timeouts give you the ability to say "give on on trying to request this service after X amount of time". It helps in the situation where a service may be down and someone is constantly trying to reach out, timeouts would help in requests hanging forever.

```
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: frontend
  namespace: microapp
spec:
  parentRefs:
  - name: frontend-gateway
  rules:
  - timeouts:
      # Increase this number if you want to
      # change the timeout period
      requests: "30s"
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - kind: Hostname
      group: networking.istio.io
      name: frontend.microapp.mesh.internal
      port: 80
EOF
```