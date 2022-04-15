#!/usr/bin/env bash

##
## This builds on shell-operator : https://github.com/flant/shell-operator
##
## Which calls the various shell scripts in /hooks
## first with "--config" to get the script configuration,
## and subsequently on every event trigger.
##

#-----------------------------------------------------------------------------------------
# This is called once by shell-operator, using the "--config" parameter
#
# See: https://github.com/flant/shell-operator#build-an-image-with-your-hooks
#
# It is used to configure the pod hook, and limit to events according to
# the defined filters
#
#-----------------------------------------------------------------------------------------
if [[ "$LOG_STATUS_CHANGE" = "true" ]]; then
  if [[ $1 == "--config" ]] ; then
cat <<EOF
configVersion: v1
kubernetes:
- apiVersion: v1
  kind: Pod
  # 
  # Because the modified event is extreamly verbose,
  #(especially with healthcheck, which updates it every X seconds)
  # when possible we will add upfront any filters we can
  # use to reduce the amount of "modified" events
  #
  executeHookOnEvent:
  - Modified
  # 
  # Limit filtering to the namespace
  #
  namespace:
    nameSelector:
      matchNames: ["${NAMESPACE}"]
  #
  # Limit filtering to changes in ready states (stored in conditions[1])
  #
  jqFilter: ".status.conditions[1].status"
EOF
  # Exit immediately, after outputting the config
  exit 0
  fi
# Even if we don't want the hook to trigger shell operator hooks needs a config, 
# Let's just add one that will never trigger.
else
  if [[ $1 == "--config" ]] ; then
cat <<EOF
configVersion: v1
kubernetes:
- apiVersion: v1
  kind: Pod
  executeHookOnEvent:
  - Deleted
  # 
  # Limit filtering to the empty namespace so it doesn't trigger
  #
  namespace:
    nameSelector:
      matchNames: ["hookwillnottrigger"]
EOF
  # Exit immediately, after outputting the config
  exit 0
  fi
fi

#-----------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------
#
# Handle the processing of events.
#
# ${BINDING_CONTEXT_PATH} is a path to .json file
# 
#-----------------------------------------------------------------------------------------

# Get the raw JSON event string, we intentionally do this only once
# to reduce the amount of IO involved in temporary files
JSON_EVENT_STR=$(cat ${BINDING_CONTEXT_PATH})

# Get the JSON object
JSON_OBJ_STR=$(echo $JSON_EVENT_STR | jq -r '.[0].object')

# Lets extract out several key values
POD_NAME=$(echo "$JSON_OBJ_STR" | jq -r '.metadata.name')

# Lets skip the pods whose names do not match
if [[ -z "$TARGETPOD" ]]; then
  # TARGETPOD parameter is empty, match all containers in namespace
	:
else
  if [[ "$POD_NAME" =~ "$TARGETPOD" ]]; then
    # TARGETPOD matches, we shall permit this event
		  :
  else
    # TARGETPOD does not match, we should skip this event
    exit 0
  fi
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
# IF STATUS LOGS AREN'T SHOWING UP MAKE SURE LOG_LEVEL IS SET TO "INFO"
if [[ "$READY" = "False" ]]; then
  echo "STATUS UPDATE ${POD_NAME} - INIT IS ${INIT} | READY IS ${READY} - ${READY_MESSAGE} : ${READY_REASON} | CONTAINER READY IS ${CONTAINER_READY} | POD SCHEDULED IS ${PODSCHEDULED} "
else 
  echo "STATUS UPDATE ${POD_NAME} - INIT IS ${INIT} | READY IS ${READY} | CONTAINER READY IS ${CONTAINER_READY} | POD SCHEDULED IS ${PODSCHEDULED} "
fi
