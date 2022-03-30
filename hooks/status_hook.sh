#!/usr/bin/env bash
if [[ $1 == "--config" ]] ; then
cat <<EOF
configVersion: v1
kubernetes:
- apiVersion: v1
  kind: Pod
  # 
  # Because the modified event is extreamly verbose,
  # (especially with healthcheck, which updates it every X seconds)
  # when possible we will add upfront any filters we can
  # use to reduce the amount of "modified" events
  #
  executeHookOnEvent:
  - Modified
  #
  # Limit filtering to changes in "state"
  #
  jqFilter: ".status.containerStatuses[0].state.terminated"
EOF
# Exit immediately, after outputting the config
exit 0
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

if [[ "$POD_NAME" =~ "failed-pod" ]]; then
  # TARGETPOD matches, we shall permit this event
	:
else
  # TARGETPOD does not match, we should skip this event
  exit 0
fi

# Get the terminated exit code and reason
TERMINATED_EXITCODE=$(echo "$JSON_OBJ_STR" | jq -r '.status.containerStatuses[0].state.terminated.exitCode')
TERMINATED_REASON=$(echo "$JSON_OBJ_STR" | jq -r '.status.containerStatuses[0].state.terminated.reason')

# Fallback to "lastState", this can happen if the contianer is started "quickly"
# before the event is properlly handled - and/or - the original event was missed
if [[ -z "$TERMINATED_EXITCODE" ]] || [[ "$TERMINATED_EXITCODE" == "null" ]]; then
  TERMINATED_EXITCODE=$(echo "$JSON_OBJ_STR" | jq '.status.containerStatuses[0].lastState.terminated.exitCode')
  TERMINATED_REASON=$(echo "$JSON_OBJ_STR" | jq '.status.containerStatuses[0].lastState.terminated.reason')
fi

# If there is no exitcode / reason, we presume its a misfied event
# so we shall ignore it
if [[ -z "$TERMINATED_EXITCODE" ]] || [[ "$TERMINATED_EXITCODE" == "null" ]]; then
  exit 0
fi

# Lets perform the termination event
echo "ACTION - terminating ${POD_NAME} which completed with exitcode ${TERMINATED_EXITCODE} : ${TERMINATED_REASON}"
kubectl delete pod --wait=false $POD_NAME 
