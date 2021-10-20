## k8-controller-pod-deletion
This controller uses k8 shell operator to bypass having to code in Golang
and directly use shell to monitor k8 pod events and react to it.

### Run

Build shell-operator image with custom script:

## Replace locahlhost:5000/ by your registry name
```
docker build -t "localhost:5000/shell-operator:monitor-pods" .    
docker push localhost:5000/shell-operator:monitor-pods
```

Edit image in shell-operator-pod.yaml and apply manifests:

```
kubectl create ns example-namespacewith-pods
kubectl -n example-namespacewith-pods apply -f shell-operator-rbac.yaml  
```

Deploy a pod (example with a failing pod for testing purpose):

```
kubectl -n  test-delete-pods apply -f https://git.io/vPieo
```

See in logs that hook was run:

```
kubectl get pods --namespace=example-namespacewith-pods
kubectl -n example-namespacewith-pods logs po/shell-operator > logs.txt
```

### cleanup of testing env /!\ DONT DO IT ON PROD
```
kubectl delete clusterrolebinding/monitor-pods
kubectl delete clusterrole/monitor-pods
kubectl delete ns/example-namespacewith-pods
docker rmi localhost:5000/shell-operator:monitor-pods
```
