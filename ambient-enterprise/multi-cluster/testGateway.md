The goal here is to destroy the app running on one cluster so you can see the multi-cluster routing truly exists.

```
kubectl scale deploy  -n NAMESPACE_FOR_YOUR_APP NAME_OF_YOUR_APP --replicas=0 --context $CLUSTER1
```

kubectl get workloadentry --all-namespaces