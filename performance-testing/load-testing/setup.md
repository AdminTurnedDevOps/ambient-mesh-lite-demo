1. Install Grafana k6.

Example: On Mac
```
brew install k6
```

2. Run the test
```
k6 run performance-testing/load-testing/load.js
```

You can also output the results to a file:
```
k6 run --out json=test-results.json performance-testing/load-testing/load.js
```

Wait about 2 minutes to get a baseline

3. Scale down the app on cluster 1 to trigger a failure
```
kubectl scale deployment/frontend --replicas=0 -n microapp --context=$CLUSTER1
```

Look at the metrics

4. Scale back up
```
kubectl scale deployment/frontend --replicas=1 -n microapp --context=$CLUSTER1
```