# k8s-pod-completion-reaper

Docker Hub location: [`uilicious/k8s-pod-completion-reaper`](https://hub.docker.com/repository/docker/uilicious/k8s-pod-completion-reaper/general)

Automatically remove kubernetes pods when they exit / restarts.

This listens to kubernetes event stream, and trigger a pod removal, while perodically scanning for any containers which been restarted, and performs removals on restarting nodes.
This effectively prevents any form of "pod restarts" from occuring, ensuring any pod startup is done "new".

This is to work around limitations in kubernetes currently.
See: https://github.com/kubernetes/kubernetes/issues/101933

This operator/container can also be adjusted to perform removal on "unhealthy" nodes (not covered in the k8s issue listed above, disabled by default)

# Production Deployment Warning

This will trigger a removal for any "restarting" or "restarted" container matching the TARGETPOD / NAMESPACE. In event that this is deployed to an existing live environment,
this may end up triggering a large number of pod removals (potentially the whole namespace) if there are multiple pods who has been restarted previously.

If the hosts does not have the required resources to handle the mass removal and replacement of of containers, this could lead to a restart loop. You are recommended instead to tune the container 
and significantly increase the `KUBECTL_POD_DELETION_WAIT` for the initial deployment, to slow down the rate of replacement (and lighten the load) or scale up your node count (and increase capacity).

If you do not need to remove existing containers, and would like to only remove remove new restarts, you may set `KUBECTL_FALLBACK_ENABLE=false` 

Alternatively, you should really test and understand how this reaper operator work in a TEST environment before deploying effectively strangers code in PRODUCTION =P

# ENV variable to configure the docker container

| Name                             | Default Value | Description                                                                                                                                           |
|----------------------------------|---------------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| NAMESPACE                        | -             | (Required) Namespace to limit the pod reaper to                                                                                                       |
| TARGETPOD                        | -             | Regex expression for matching POD, to apply the k8s-pod-completion-reaper to, if blank, matches all containers in the namespace                       |
| APPLY_ON_EXITCODE_0              | true          | If true, Terminate and remove the pods, even if the exit code was 0 (aka, it exited without error)                                                    |
| DEBUG                            | false         | If true, perform no action and logs it instead                                                                                                        |
| LOG_LEVEL                        | error         | Log level, of shell-operator, use either "debug","info" or "error"                                                                                    |
| SHELL_OPERATOR_ENABLE            | true          | Enable the use of the main shell-operator workflow, which would react quicker in a "live" manner                                                      |
| KUBECTL_FALLBACK_ENABLE          | true          | Enable the inbuilt kubectl fallback behaviour, which triggers on a perodic basis                                                                      |
| KUBECTL_POLLING_INTERVAL         | 30s           | Polling interval to wait between scans, note due to POD_DELETION_WAIT actual interval maybe significant longer                                        |
| KUBECTL_POD_DELETION_WAIT        | 10s           | Number of seconds for kubectl to wait between deletion command, this can be used to limit the number of containers being restarted at the "same time" |
| KUBECTL_MIN_AGE_IN_MINUTES       | 5             | Minimum age of the kubectl pod to be considered valid for kubectl fallback evaluation                                                                 |
| KUBECTL_APPLY_ON_UNHEALTHY_NODES | false         | Optionally, pre-emptively terminate unhealthy node, allowing a new pod to be created earlier                                                          |

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
