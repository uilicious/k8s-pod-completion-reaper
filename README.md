### k8-controller-pod-deletion
This controller uses k8 shell operator to bypass having to code in Golang
and directly use shell to monitor k8 pod events and react to it.

### Setup

## ENV Variables
Set target namespace for event listening
    - name: TARGETNAMESPACE
      value: "test-ns"
Set target to a string or regex, hook will only trigger if pod's name matchs target
    - name: TARGETPOD
      value: "termination"
Set debug to "true" if you just want logs when the hook triggers
    - name: DEBUG
      value: "true" 

## Build operator image and push to your registry
```
docker build -t "localhost:5000/shell-operator:delete-pods" .    
docker push localhost:5000/shell-operator:delete-pods
```
### Run & Test

## Create namespace if necessary and deploy pod

```
kubectl create ns test-ns
kubectl -n test-ns apply -f shell-operator-rbac.yaml  
```

Deploy a test od (example with a failing pod for testing purpose):

1) busybox image - will sleep 1h
2) Termination pod - will directly crash
```
kubectl -n  test-ns apply -f https://git.io/vPieo
or 
kubectl -n test-ns apply -f https://k8s.io/examples/debug/termination.yaml
or 
test from inside a pod (suicide): kill -SIGTERM 1
```

Check pods status in namespace and 
see in logs that hook was run:

```
kubectl get pods --namespace=test-ns
kubectl -n test-ns logs po/pod-reaper > logs.txt
```

### cleanup of testing env 
```
kubectl delete rolebinding/reap-pods
kubectl delete role/reap-pods
kubectl delete ns/test-ns
```

