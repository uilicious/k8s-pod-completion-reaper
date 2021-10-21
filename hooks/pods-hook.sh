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
  podReason=$(jq -r '.[0].object.status.containerStatuses[0].state.terminated.reason' ${BINDING_CONTEXT_PATH}) #${BINDING_CONTEXT_PATH} is a path to .json file
  if [[ $podReason == *'Completed'* ]]; then #Check if  logs contain "reason": "Completed" (might want to go for "CrashLoopBackOff" if this is too frequent)
    podName=$(jq -r '.[0].object.metadata.name' ${BINDING_CONTEXT_PATH})
    if [[ $podName == *$TARGET* ]]; then #Might want to use regex but I have no clue what name the target pods will have so this is enough for testing purposes
      kubectl delete pod $podName
      echo 'POD STATUS IS COMPLETED - WOULD DELETE:' $podName
    fi
  fi
fi


