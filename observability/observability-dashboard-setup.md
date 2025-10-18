Below are some metrics that you can use to create your own Grafana dashboard if you're testing multi-cluster failover.

1. Connection Metrics (Most Important for L4 failover)
- `istio_tcp_connections_opened_total` - You'll see connections to cluster1 drop to zero, cluster2 increase
- `istio_tcp_connections_closed_total` - Spike when cluster1 pods are killed
- `istio_tcp_sent_bytes_total by destination_cluster` - Shows traffic shift visually
- `istio_tcp_sent_bytes_total` - Traffic Volume by Cluster (Best indicator)