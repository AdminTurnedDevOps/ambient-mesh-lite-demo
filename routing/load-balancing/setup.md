Load balancing helps route traffic based on:

- ROUND_ROBIN: Requests forwarded to each instance in sequence
- LEAST_REQUEST: Requests distributed to instances with fewest requests (default)
- RANDOM: Requests forwarded randomly to instances
- PASSTHROUGH: No load balancing, let underlying network handle it

```
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: frontend
spec:
  host: frontend.microapp.mesh.internal
  trafficPolicy:
    loadBalancer:
      simple: ROUND_ROBIN
```