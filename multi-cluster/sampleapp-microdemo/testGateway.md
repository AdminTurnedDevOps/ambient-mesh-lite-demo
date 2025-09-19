```
kubectl scale deploy  -n microapp frontend --replicas=1 --context $CLUSTER1
```

kubectl get workloadentry --all-namespaces