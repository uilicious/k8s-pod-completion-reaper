#!/usr/bin/env bash
if [[ $1 == "--config" ]] ; then
cat <<EOF
configVersion: v1
kubernetes:
- apiVersion: v1
  kind: Pod
  #
  executeHookOnEvent:
  - Modified
  #
  # Limit filtering to changes in ready states (stored in conditions[1])
  #
  jqFilter: ".status.conditions[1].status"
EOF
exit 0
fi
# Get the raw JSON event string, we intentionally do this only once
# to reduce the amount of IO involved in temporary files
JSON_EVENT_STR=$(cat ${BINDING_CONTEXT_PATH})

#Can't check if enabled earlier in code because hooks need at least have one property
if [[ "$ENABLE_STATUS_HOOK" = "true" ]] ; then
    # Get the JSON object
    JSON_OBJ_STR=$(echo $JSON_EVENT_STR | jq -r '.[0].object')
    # Lets extract out several key values
    POD_NAME=$(echo "$JSON_OBJ_STR" | jq -r '.metadata.name')

    if [[ "$POD_NAME" =~ "$TARGETPOD" ]]; then
    # TARGETPOD matches, we shall permit this event
	    :
    else
        # TARGETPOD does not match, we should skip this event
        exit 0
    fi
    # SEE POD CONDITIONS FROM OFFICIAL DOC
    # https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/
    INIT=$(echo "$JSON_OBJ_STR" | jq -r '.status.conditions[0].status')
    # 
    READY=$(echo "$JSON_OBJ_STR" | jq -r '.status.conditions[1].status')
    READY_MESSAGE=$(echo "$JSON_OBJ_STR" | jq -r '.status.conditions[1].message')
    READY_REASON=$(echo "$JSON_OBJ_STR" | jq -r '.status.conditions[1].reason')
    # 
    CONTAINER_READY=$(echo "$JSON_OBJ_STR" | jq -r '.status.conditions[2].status')
    #CONTAINER_READY_MESSAGE=$(echo "$JSON_OBJ_STR" | jq -r '.status.conditions[2].message')
    #CONTAINER_READY_REASON=$(echo "$JSON_OBJ_STR" | jq -r '.status.conditions[2].reason')
    # 
    PODSCHEDULED=$(echo "$JSON_OBJ_STR" | jq -r '.status.conditions[3].status')

    #READY status only include message if false, let's avoid confusing someone by printing null
    if [[ "$READY" = "False" ]]; then
        echo "STATUS UPDATE ${POD_NAME} - INIT IS ${INIT} | READY IS ${READY} - ${READY_MESSAGE} : ${READY_REASON} | CONTAINER READY IS ${CONTAINER_READY} | POD SCHEDULED IS ${PODSCHEDULED} "
    else 
        echo "STATUS UPDATE ${POD_NAME} - INIT IS ${INIT} | READY IS ${READY} | CONTAINER READY IS ${CONTAINER_READY} | POD SCHEDULED IS ${PODSCHEDULED} "
    fi
fi
#-----------------------------------------------------------------------------------------
