As you're going through this setup, you'll see two primary methods to get Istio, Gloo Mesh, and Gloo Gateway configured:

1. With the Gloo Mesh Operator
2. With Helm

Both are great options and yet, are a bit different in terms of overall configuration.

With the Gloo Mesh Operator, it's doing a lot of the "heavy lifting" for you. For example, it will do things like automatically install Istio and Ztunnel if in Ambient mode.

You'll also see some other levels of automation at times like using the `istio.io/use-waypoint=auto` label, which automatically creates a Waypoint (Gateway) for a Namespace (if you use said label on the Namespace).

With Helm, you'll have more of a "controlled" experience as there's a Helm Chart and Kubernetes Manifest config for each implementation (Istio, Ztunnel, Gateways, etc.)

Please note that this is for "single cluster"