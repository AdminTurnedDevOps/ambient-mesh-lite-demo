As you're going through this setup, you'll see several methods to get Istio Ambient OSS, Gloo Mesh, and Gloo Gateway configured:

1. With the Gloo Mesh Operator
2. With Helm
3. OSS installations
4. Enterprise installations
5. GitOps configurations
6. Sample application deployments to test scale and observability

With the Gloo Mesh Operator, it's doing a lot of the "heavy lifting" for you. For example, it will do things like automatically install Istio and Ztunnel if in Ambient mode.

You'll also see some other levels of automation at times like using the `istio.io/use-waypoint=auto` label, which automatically creates a Waypoint (Gateway) for a Namespace (if you use said label on the Namespace).

With Helm, you'll have more of a "controlled" experience as there's a Helm Chart and Kubernetes Manifest config for each implementation (Istio, Ztunnel, Gateways, etc.)