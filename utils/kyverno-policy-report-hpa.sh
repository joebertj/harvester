#kubectl rollout restart deployment fastapi-metrics-app -n harvester-autoscaling-sim
#kubectl rollout restart deployment kyverno -n kyverno
kubectl get policyreport -n harvester-autoscaling-sim -o json | python3 -c "
import json, sys
data = json.load(sys.stdin)
for r in data.get('items', []):
    for res in r.get('results', []):
        if res.get('result') == 'fail':
            name = res['resources'][0]['name'] if res.get('resources') else '?'
            print(f\"{res['policy']:35s} {res['resources'][0]['kind']}/{name}\")
" | sort -u
