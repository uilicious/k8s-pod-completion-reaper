# k8s-pod-completion-reaper

Automatically remove kubernetes pods when they exit / restarts.

This listens to kubernetes event stream, and trigger a pod removal. In event it exits.
This effectively prevents any form of "pod restarts" from occuring, ensuring any pod startup is done "new".

This is to work around limitations in kubernetes currently.
See: https://github.com/kubernetes/kubernetes/issues/101933

# ENV variable to configure the docker container

| Name                | Default Value | Description                                                                                        |
|---------------------|---------------|----------------------------------------------------------------------------------------------------|
| NAMESPACE           | -             | (Required) Namespace to limit the pod reaper to                                                    |
| TARGETPOD           | -             | Regex expression for matching POD, to apply the k8s-pod-completion-reaper to                       |
| APPLY_ON_EXITCODE_0 | true          | If true, Terminate and remove the pods, even if the exit code was 0 (aka, it exited without error) |
| DEBUG               | false         | If true, perform no action and logs it instead.                                                    |
| LOG_LEVEL           | error         | Log level, of shell-operator, use either "debug","info" or "error"                                 |

# Deployment

For the docker container to work, you will first need to setup the kubernetes RBAC.

```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pod-reaper-svc-acc
  namespace: proj-namespace
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reaper-role
  namespace: proj-namespace
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list","delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-reaper-role
  namespace: proj-namespace
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-reaper-role
subjects:
  - kind: ServiceAccount
    name: pod-reaper-svc-acc
    namespace: proj-namespace
```

Once the RBAC is succesfully setup, you can deploy the k8s-pod-completion-reaper operator.

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pod-completion-reaper
  namespace: proj-namespace
spec:
  selector:
    matchLabels:
      app: pod-completion-reaper
  replicas: 1
  template:
    metadata:
      labels:
        app: pod-completion-reaper
    spec:
      containers:
      - name: pod-completion-reaper
        image: "uilicious/pod-completion-reaper"
        env: 
          - name: "NAMESPACE"
            value: "proj-namespace"
```

# Misc: Development Notes

This is built on the shell-operator project
See: https://github.com/flant/shell-operator

Because the "object" definition is nearly impossible to find definitively online, if you want to understand each
object provided by ".[0].object", you may want to refer to either an existing cluster with `kubectl get pods -o json`
or alternatively [./notes/example-pod.yaml](./notes/example-pod.yaml).

This uses the APACHE license, to ensure its compatible with the shell-operator its built on.









---

### Build operator image and push to your registry
```
docker build -t "remyuilicious/k8control:delete-pods" .    
docker push remyuilicious/k8control:delete-pods
```
## Run & Test

### Create namespace if necessary and deploy pod

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
kubectl delete rolebinding/pod-reaper-role
kubectl delete role/pod-reaper-role
kubectl delete ns/test-ns
```

