### k8-controller-pod-deletion
This controller uses k8 shell operator to bypass having to code in Golang
and directly use shell to monitor k8 pod events and react to it.

### Run & Test

Change env variable in shell-operator-rbac.yaml to whatever pod names you want to target:

env:
    - name: TARGET
      value: "termination"

Will terminate any completed pods that include "termination" in its name (We use https://k8s.io/examples/debug/termination.yaml as a test example)

## Build operator image and push to your registry
```
docker build -t "remyuilicious/k8control:delete-pods" .    
docker push remyuilicious/k8control:delete-pods
```

## Create namespace if necessary and deploy pod

```
kubectl create ns test-delete-pods
kubectl -n test-delete-pods apply -f shell-operator-rbac.yaml  
```

Deploy a test od (example with a failing pod for testing purpose):

```
kubectl -n  test-delete-pods apply -f https://git.io/vPieo
or 
kubectl -n test-delete-pods  apply -f https://k8s.io/examples/debug/termination.yaml
```

See in logs that hook was run:

```
kubectl get pods --namespace=test-delete-pods
kubectl -n test-delete-pods logs po/shell-operator > logs.txt
```

### cleanup of testing env /!\ DONT DO IT ON PROD
```
kubectl delete clusterrolebinding/monitor-pods
kubectl delete clusterrole/monitor-pods
kubectl delete ns/test-delete-pods
```
