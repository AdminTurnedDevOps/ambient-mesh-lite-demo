import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('error_rate');
const successRate = new Rate('success_rate');
const requestDuration = new Trend('request_duration');

export const options = {
  stages: [
    { duration: '1m', target: 50 },   // Ramp up to 50 users over 1 minute
    { duration: '5m', target: 50 },   // Stay at 50 users for 5 minutes (steady state - when you'll trigger failures)
    { duration: '1m', target: 100 },  // Spike to 100 users for 1 minute (optional - to test under higher load)
    { duration: '3m', target: 100 },  // Maintain 100 users (when you can test recovery)
    { duration: '1m', target: 0 },    // Ramp down to 0 users
  ],
  thresholds: {
    'http_req_duration': ['p(95)<500'],  // 95% of requests should be below 500ms
    'error_rate': ['rate<0.1'],          // Error rate should be less than 10%
    'http_req_failed': ['rate<0.1'],     // Less than 10% failed requests
  },
};

export default function () {
  // Replace with your actual ingress gateway URL
  const url = 'http://34.139.159.214';
  
  const response = http.get(url);
  
  // Record custom metrics
  requestDuration.add(response.timings.duration);
  errorRate.add(response.status !== 200);
  successRate.add(response.status === 200);
  
  // Check if the request was successful
  const checkResult = check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
  
  // Brief pause between requests
  sleep(1);
}