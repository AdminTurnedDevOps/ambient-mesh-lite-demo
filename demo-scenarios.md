Want to test something out?

### Single Cluster Ambient Setup

1. Go to the single-cluster directory
2. Install Ambient via the `install-ambient.md` file
3. Install the Gloo Mesh Management Pane via the `install-gloo-mesh-ui.md` file

### Multi-Cluster Ambient With App

1. Go to the multi-cluster directory
2. Deploy the two GKE clusters (one is in `gke1` and the other is in `gke2`)
3. Go through the `setup.md`
4. Go through the `setup.md` in the `sampleapp-microdemo` directory

### Metrics & Telemetry

1. Deploy a cluster
2. Go to the observability directory
3. Install Ambient Mesh in the `install.md` file
4. Install and configure Kube-Prometheus in the `observability.md` file

### Failover Setup

1. Deploy everything under the **Multi-Cluster Ambient With App** section
2. Deploy everything under the **Metrics & Telemetry** section
3. Create the `DestinationRule` for circuit breaking (connection pools and outlier detection) under **performance-testing/circuit-breaking/setup.md**
4. Install and configure k6 (OSS performance testing tool from Grafana) under **performance-testing/load-testing/setup.md** 