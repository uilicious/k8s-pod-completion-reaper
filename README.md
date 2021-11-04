# k8s-pod-completion-reaper

Automatically remove kubernetes pods when they exit / restarts.

This listens to kubernetes event stream, and trigger a pod removal. In event it exits.
This effectively prevents any form of "pod restarts" from occuring, ensuring any pod startup is done "new".

This is to work around limitations in kubernetes currently.
See: https://github.com/kubernetes/kubernetes/issues/101933

Docker Hub location: [`uilicious/k8s-pod-completion-reaper`](https://hub.docker.com/repository/docker/uilicious/k8s-pod-completion-reaper/general)

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
        image: "uilicious/k8s-pod-completion-reaper"
        env: 
          - name: "NAMESPACE"
            value: "proj-namespace"
```

# Testing a deployment

If you can access the bash terminal of a pod, you can cause it to terminate on itself with 

```
kill -SIGTERM 1
```

Alternatively you can deploy a pod, which will terminates itself every 30 seconds

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: termination-demo
  namespace: proj-namespace
spec:
  selector:
    matchLabels:
      app: termination-demo-container
  replicas: 3
  template:
    metadata:
      labels:
        app: termination-demo-container
    spec:
      containers:
      - name: termination-demo-container
        image: busybox
        command: ["/bin/sh"]
        args: ["-c", "sleep 30 && echo 'Sleep expired'"]
```

Alternatively use busybox image itself - and let it sleep for 1h

# Misc: Development Notes

This is built on the shell-operator project
See: https://github.com/flant/shell-operator

Because the "object" definition is nearly impossible to find definitively online, if you want to understand each
object provided by ".[0].object", you may want to refer to either an existing cluster with `kubectl get pods -o json`
or alternatively [./notes/example-pod.yaml](./notes/example-pod.yaml).

This uses the APACHE license, to ensure its compatible with the shell-operator its built on.
