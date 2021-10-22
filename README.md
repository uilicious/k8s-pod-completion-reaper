### k8-controller-pod-deletion
This controller uses k8 shell operator to bypass having to code in Golang
and directly use shell to monitor k8 pod events and react to it.

### Run & Test

## ENV Variables
env:
# Set target to a string or regex, hook will only trigger if pod's name matchs target
    - name: TARGET
      value: "termination"
# Set debug to "true" if you just want logs when the hook triggers
    - name: DEBUG
      value: "true" 

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

1) busybox image - will sleep 1h
2) Termination pod - will directly crash
```
kubectl -n  test-delete-pods apply -f https://git.io/vPieo
or 
kubectl -n test-delete-pods  apply -f https://k8s.io/examples/debug/termination.yaml
```

Check pods status in namespace and 
see in logs that hook was run:

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
