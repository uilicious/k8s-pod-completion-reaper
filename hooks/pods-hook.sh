#!/usr/bin/env bash

if [[ $1 == "--config" ]] ; then
  cat <<EOF
configVersion: v1
kubernetes:
- apiVersion: v1
  kind: Pod
  executeHookOnEvent:
  - Modified
EOF
else
  podReason=$(jq -r '.[0].object.status.containerStatuses[0].state.terminated.reason' ${BINDING_CONTEXT_PATH}) #${BINDING_CONTEXT_PATH} is ./pathtofile.json)
  if [[ $podReason == *'Completed'* ]]; then #Check if  logs contain "reason": "Completed" (might want to go for "CrashLoopBackOff instead")
    podName=$(jq -r '.[0].object.metadata.name' ${BINDING_CONTEXT_PATH})
    #kubectl delete pod $podName
    echo 'POD STATUS IS COMPLETED - WOULD DELETE:' $podName
    #jq -r '.[0].object.metadata.namespace' ${BINDING_CONTEXT_PATH}
    #jq -r '.[0].object.status.containerStatuses[0].containerID' ${BINDING_CONTEXT_PATH}
  fi
fi


