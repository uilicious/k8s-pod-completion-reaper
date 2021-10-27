#!/usr/bin/env bash

if [[ $1 == "--config" ]] ; then
  cat <<EOF
configVersion: v1
kubernetes:
- apiVersion: v1
  kind: Pod
  executeHookOnEvent:
  - Modified
  namespace:
    nameSelector:
      matchNames: ["${TARGETNAMESPACE}"]
EOF
else
  podName=$(jq -r '.[0].object.metadata.name' ${BINDING_CONTEXT_PATH})
  podReason=$(jq -r '.[0].object.status.containerStatuses[0].state.terminated.reason' ${BINDING_CONTEXT_PATH}) #${BINDING_CONTEXT_PATH} is a path to .json file
  if [[ $podReason == *'Unhealthy'* ]]; then
    echo "DEBUG - pod ${podName} in namespace ${TARGETNAMESPACE} is unhealthy"
  fi
  if [[ $podReason == *'Completed'* ]]; then #Check if  logs contain "reason": "Completed" (might want to go for "CrashLoopBackOff" if this is too frequent)
    if [ $DEBUG = 'true' ] ; then
      echo "DEBUG - would delete pod ${podName} in namespace ${TARGETNAMESPACE}, reason: ${podReason}"
    else
      if  [[  -z  $TARGETPOD  ]] ; then
        kubectl delete pod --wait=false $podName 
        echo "ACTION - target is any pods in namespace ${TARGETNAMESPACE}, deleting pod ${podName}, reason: ${podReason}"
      else
        if [[ $podName =~ $TARGETPOD ]] ; then
          kubectl delete pod --wait=false $podName 
          echo "ACTION - target is ${TARGETPOD} in namespace ${TARGETNAMESPACE}, deleting pod ${podName}, reason: ${podReason}"
        fi
      fi
    fi
  fi
fi


