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
  if [[ $podReason == *'Unhealthy'* ]]; then
    echo 'DEBUG - POD IS UNHEALTHY'
  fi
  if [[ $podReason == *'Completed'* ]]; then #Check if  logs contain "reason": "Completed" (might want to go for "CrashLoopBackOff" if this is too frequent)
    podName=$(jq -r '.[0].object.metadata.name' ${BINDING_CONTEXT_PATH})
    if [ $DEBUG = 'true' ] ; then
      echo 'DEBUG - POD STATUS IS COMPLETED - WOULD DELETE:' $podName
    else
      if  [[  -z  $TARGET  ]] ; then
        kubectl delete pod --wait=false $podName 
        echo 'POD STATUS IS COMPLETED - DELETED:' $podName
      else
        if [[ $podName =~ $TARGET ]] ; then
          kubectl delete pod $podName 
          echo 'POD STATUS IS COMPLETED - DELETED:' $podName
        fi
      fi
    fi
  fi
fi


