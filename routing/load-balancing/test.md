## Test

This test provides cookie-based load balancing. This is a good visual for a few reasons:
1. It shows that the consistent hashing works.
2. `user-id` always hits the same pod

```
kubectl exec -it deployment/web -n emojivoto -- /bin/sh -c '
echo "🎯 Sticky Session Test - Same User = Same Pod! 🎯";
echo "";
users=("😀alice" "😎bob" "🤠charlie" "😀alice" "😎bob" "🤠charlie" "😀alice");
for user in "${users[@]}"; do
  echo "Testing user: $user";
  pod_ip=$(curl -s -H "user-id: ${user#*}" -w "%{remote_ip}" -o /dev/null http://web-svc);
  echo "  → Routed to pod: $pod_ip";
  echo "";
  sleep 0.5;
done;
echo "👀 Notice: Same emoji users should hit the same pod IPs!"'
```