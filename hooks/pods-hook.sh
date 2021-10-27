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
  #namespace=$(jq -r '.[0].object.metadata.namespace' ${BINDING_CONTEXT_PATH})
  podName=$(jq -r '.[0].object.metadata.name' ${BINDING_CONTEXT_PATH})
  podReason=$(jq -r '.[0].object.status.containerStatuses[0].state.terminated.reason' ${BINDING_CONTEXT_PATH}) #${BINDING_CONTEXT_PATH} is a path to .json file
  if [[ $podReason == *'Unhealthy'* ]]; then
    echo "DEBUG - pod ${podName} is unhealthy"
  fi
  if [[ $podReason == *'Completed'* ]]; then #Check if  logs contain "reason": "Completed" (might want to go for "CrashLoopBackOff" if this is too frequent)
    if [ $DEBUG = 'true' ] ; then
      echo "DEBUG - would delete pod ${podName}, reason: ${podReason}"
    else
      if  [[  -z  $TARGET  ]] ; then
        kubectl delete pod --wait=false $podName 
        echo "ACTION - target is entier namespace, deleting pod ${podName}, reason: ${podReason}"
      else
        if [[ $podName =~ $TARGET ]] ; then
          kubectl delete pod --wait=false $podName 
          echo "ACTION - target is ${TARGET}, deleting pod ${podName}, reason: ${podReason}"
        fi
      fi
    fi
  fi
fi


