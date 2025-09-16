## Test
The below test does the following:
- Sends 50 concurrent requests to overwhelm the emoji service (triggers circuit breaker)
- Waits for them to complete
- Tests 5 more requests to see circuit breaker in action

You should see `200` requests as normal, but after the overload, some `503` responses with ~0.001s timing for immediate rejection

The reason this works is if you look in `destinationRule.yaml`, the limit is set to 10 max connections.

```
kubectl exec -it deployment/web -n emojivoto -- bash -c '
echo "Testing with relaxed settings:";
for i in 1 2 3; do 
  echo -n "Request $i: ";
  curl -s -o /dev/null -w "%{http_code} - %{time_total}s\n" http://emoji-svc:8080/api/list;
done'
```