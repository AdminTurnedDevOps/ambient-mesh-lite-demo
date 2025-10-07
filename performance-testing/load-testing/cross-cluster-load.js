import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend, Gauge } from 'k6/metrics';

// Custom metrics for cross-cluster scenarios
const crossClusterRequests = new Counter('cross_cluster_requests');
const meshLatency = new Trend('mesh_latency');
const clusterFailovers = new Counter('cluster_failovers');
const activeConnections = new Gauge('active_connections');
const errorsByCluster = new Counter('errors_by_cluster');

export const options = {
  stages: [
    { duration: '2m', target: 50 },   // Warm up
    { duration: '5m', target: 200 },  // Normal load across clusters
    { duration: '3m', target: 500 },  // High load to test mesh performance
    { duration: '5m', target: 200 },  // Back to normal
    { duration: '2m', target: 0 },    // Cool down
  ],
  thresholds: {
    'http_req_duration': ['p(95)<1000', 'p(99)<2000'],
    'mesh_latency': ['p(95)<800'],
    'http_req_failed': ['rate<0.05'],
    'cross_cluster_requests': ['count>1000'],
  },
};

// Test scenarios for different service endpoints
const scenarios = {
  frontend: { weight: 40, path: '/' },
  static: { weight: 30, path: '/static/style.css' },
  cart: { weight: 20, path: '/cart' },
  product: { weight: 10, path: '/product/66VCHSJNUP' }
};

export default function () {
  // Simulate multi-cluster traffic patterns
  const baseUrl = 'http://34.139.159.214';
  
  // Select random scenario based on weights
  const rand = Math.random() * 100;
  let scenario;
  let cumWeight = 0;
  
  for (const [name, config] of Object.entries(scenarios)) {
    cumWeight += config.weight;
    if (rand <= cumWeight) {
      scenario = { name, ...config };
      break;
    }
  }
  
  const url = `${baseUrl}${scenario.path}`;
  const startTime = Date.now();
  
  // Add headers to simulate realistic traffic
  const headers = {
    'User-Agent': 'k6-ambient-mesh-test',
    'Accept': 'application/json',
    'X-Test-Scenario': scenario.name,
    'X-Cluster-Source': Math.random() > 0.5 ? 'cluster1' : 'cluster2'
  };
  
  const response = http.get(url, { headers });
  const endTime = Date.now();
  
  // Record metrics
  crossClusterRequests.add(1);
  meshLatency.add(endTime - startTime);
  activeConnections.add(1);
  
  // Track errors by scenario/cluster
  if (response.status !== 200) {
    errorsByCluster.add(1, { cluster: headers['X-Cluster-Source'], scenario: scenario.name });
  }
  
  // Enhanced checks for ambient mesh
  const checkResult = check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 1s': (r) => r.timings.duration < 1000,
    'has ambient mesh headers': (r) => {
      // Check for Istio ambient mesh specific headers
      const headers = r.headers;
      return headers['x-envoy-upstream-service-time'] !== undefined ||
             headers['x-request-id'] !== undefined;
    },
    'content length > 0': (r) => r.body.length > 0,
  });
  
  // Simulate different user behavior patterns
  if (scenario.name === 'crossCluster') {
    // Cross-cluster calls might need more time
    sleep(Math.random() * 2 + 1);
  } else {
    sleep(Math.random() + 0.5);
  }
  
  // Occasionally simulate burst traffic
  if (Math.random() < 0.1) {
    for (let i = 0; i < 3; i++) {
      const burstResponse = http.get(url, { headers });
      crossClusterRequests.add(1);
      sleep(0.1);
    }
  }
}