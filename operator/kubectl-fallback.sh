#!/bin/bash

#
# This scripts, is considered a fallback script from the "hooks"
# and is intended to catch any pods, that were missed by the pod hooks
#
# This can happen on delayed basis, unlike the "live" nature of the hooks.
#

# Import the kubectl-helper-lib
source "./kubectl-helper-lib.sh"


#
# The main core loop, to perodically run the reaper operations
#
while [[ true ]]; do
    # Get the pod object list
    POD_OBJ_LIST_JSON=$(kubectl get pods --namespace="$NAMESPACE" -o json | jq '.items')

    # And process it, see kubectl-helper-lib.sh for the function
    PROCESS_POD_OBJ_LIST_JSON

    # Wait between steps
    sleep "$KUBECTL_POLLING_INTERVAL"
done
