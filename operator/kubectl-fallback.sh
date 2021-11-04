#!/bin/bash

#
# This scripts, is considered a fallback script from the "hooks"
# and is intended to catch any pods, that were missed by the pod hooks
#
# This can happen on delayed basis, unlike the "live" nature of the hooks.
#


#
# POD function, which works on a single POD_OBJ json
# and handle any, if required, terminations
#
# This requires the POD_OBJ_JSON to be set
#
POD_OBJ_JSON="null"
function PROCESS_POD_OBJ_JSON {
	
}




#
# The main core loop, to perodically run the reaper operations
#


#
# The core inner function
#
POD_LIST_JSON=$(kubectl get pods --namespace="$NAMESPACE" -o json | jq '.items')

IDX="0"

POD_OBJ=$(echo "$POD_LIST_JSON" | js ".[$IDX]")