import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Trend, Gauge } from 'k6/metrics';
import exec from 'k6/execution';

// Resilience-focused metrics
const failoverEvents = new Counter('failover_events');
const recoveryTime = new Trend('recovery_time');
const errorSpikes = new Counter('error_spikes');
const circuitBreakerTrips = new Counter('circuit_breaker_trips');
const meshResilienceScore = new Gauge('mesh_resilience_score');
const consecutiveFailures = new Counter('consecutive_failures');

export const options = {
  scenarios: {
    // Baseline load during the entire test
    baseline_load: {
      executor: 'constant-vus',
      vus: 50,
      duration: '15m',
    },
    // Spike testing to trigger failover conditions
    spike_load: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 0 },    // Wait for baseline
        { duration: '2m', target: 300 },   // Sudden spike
        { duration: '2m', target: 300 },   // Maintain spike
        { duration: '1m', target: 0 },     // Drop
        { duration: '2m', target: 0 },     // Recovery period
        { duration: '1m', target: 400 },   // Second spike
        { duration: '1m', target: 400 },   // Maintain
        { duration: '1m', target: 0 },     // Final drop
      ],
    },
  },
  thresholds: {
    'http_req_duration': ['p(95)<2000'],
    'http_req_failed': ['rate<0.15'],  // Allow higher failure rate during chaos
    'recovery_time': ['p(95)<30000'],   // Recovery within 30s
    'mesh_resilience_score': ['value>0.7'], // Maintain 70% resilience
  },
};

// Track failure states
let consecutiveFailureCount = 0;
let lastFailureTime = 0;
let isInFailureState = false;

export default function () {
  const baseUrl = 'http://34.23.86.111/';
  const testId = exec.scenario.name;
  
  // Different endpoints to test various failure modes based on Online Boutique app
  const endpoints = [
    { path: '/', weight: 30, criticalness: 1.0 },
    { path: '/cart', weight: 25, criticalness: 0.8 },
    { path: '/product/66VCHSJNUP', weight: 20, criticalness: 0.9 },
    { path: '/static/style.css', weight: 15, criticalness: 0.6 },
    { path: '/static/js/main.js', weight: 10, criticalness: 0.5 }
  ];
  
  // Select endpoint based on weight
  const rand = Math.random() * 100;
  let cumWeight = 0;
  let selectedEndpoint;
  
  for (const endpoint of endpoints) {
    cumWeight += endpoint.weight;
    if (rand <= cumWeight) {
      selectedEndpoint = endpoint;
      break;
    }
  }
  
  const url = `${baseUrl}${selectedEndpoint.path}`;
  const requestStart = Date.now();
  
  // Add chaos engineering headers
  const headers = {
    'User-Agent': 'k6-resilience-test',
    'X-Test-Type': 'resilience',
    'X-Scenario': testId,
    'X-Critical-Level': selectedEndpoint.criticalness.toString(),
    'X-Chaos-Test': 'enabled'
  };
  
  const response = http.get(url, { 
    headers,
    timeout: '10s'  // Longer timeout for resilience testing
  });
  
  const requestEnd = Date.now();
  const responseTime = requestEnd - requestStart;
  
  // Analyze response for resilience patterns
  const isFailure = response.status !== 200;
  const isTimeout = response.status === 0;
  const isServerError = response.status >= 500;
  
  // Track consecutive failures
  if (isFailure) {
    consecutiveFailureCount++;
    lastFailureTime = requestEnd;
    
    if (consecutiveFailureCount >= 3 && !isInFailureState) {
      failoverEvents.add(1);
      isInFailureState = true;
    }
    
    consecutiveFailures.add(1, { 
      endpoint: selectedEndpoint.path,
      type: isTimeout ? 'timeout' : (isServerError ? 'server_error' : 'other')
    });
    
    if (consecutiveFailureCount >= 5) {
      circuitBreakerTrips.add(1);
    }
  } else {
    // Recovery detected
    if (isInFailureState && consecutiveFailureCount > 0) {
      const recoveryDuration = requestEnd - lastFailureTime;
      recoveryTime.add(recoveryDuration);
      isInFailureState = false;
    }
    consecutiveFailureCount = 0;
  }
  
  // Calculate resilience score
  const errorRate = consecutiveFailureCount / (consecutiveFailureCount + 1);
  const timeoutPenalty = isTimeout ? 0.2 : 0;
  const criticalnessFactor = selectedEndpoint.criticalness;
  const resilienceScore = Math.max(0, (1 - errorRate - timeoutPenalty) * criticalnessFactor);
  meshResilienceScore.add(resilienceScore);
  
  // Enhanced checks for resilience testing
  check(response, {
    'request completed': (r) => r.status !== 0,
    'acceptable response time': (r) => r.timings.duration < 5000,
    'no connection refused': (r) => !r.body.includes('connection refused'),
    'ambient mesh active': (r) => {
      // Check for Istio sidecar injection indicators
      return r.headers['server'] !== undefined || 
             r.headers['x-envoy-upstream-service-time'] !== undefined;
    },
    'graceful degradation': (r) => {
      // Even during failures, should get some response
      return r.status === 200 || r.status === 503 || r.status === 429;
    }
  });
  
  // Error spike detection
  if (isFailure && responseTime > 2000) {
    errorSpikes.add(1);
  }
  
  // Adaptive sleep based on current state
  if (isInFailureState) {
    // Reduce load during failure state to allow recovery
    sleep(Math.random() * 3 + 2);
  } else if (testId === 'spike_load') {
    // Aggressive load during spike testing
    sleep(Math.random() * 0.5);
  } else {
    // Normal baseline behavior
    sleep(Math.random() * 2 + 1);
  }
  
  // Simulate real user retry behavior
  if (isFailure && selectedEndpoint.criticalness > 0.8) {
    sleep(1); // Wait before retry
    const retryResponse = http.get(url, { headers });
    
    check(retryResponse, {
      'retry successful': (r) => r.status === 200
    });
  }
}