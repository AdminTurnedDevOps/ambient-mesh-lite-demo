```
git clone https://github.com/digitalocean/kubernetes-sample-apps.git
```

```
kubectl create ns emojivoto
```

```
kubectl label ns emojivoto istio.io/dataplane-mode=ambient
```

```
cd kubernetes-sample-apps/emojivoto-example
```

```
kubectl apply -k kustomize/
```

```
kubectl get pods -n emojivoto
```

```
kubectl label namespace emojivoto istio.io/usewaypoint=auto
```