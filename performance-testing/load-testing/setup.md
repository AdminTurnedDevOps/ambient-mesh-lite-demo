1. Install Grafana k6.

Example: On Mac
```
brew install k6
```

2. Run the test
```
k6 run --out json=test-results.json performance-testing/load-testing/load.js
```