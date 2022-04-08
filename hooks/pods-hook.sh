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
  # Limit filtering to the namespace
  #
  namespace:
    nameSelector:
      matchNames: ["${NAMESPACE}"]
  #
  # Limit filtering to changes in "state"
  # note that i suspect this is done on the shell-operator
  # side (not the k8s cluster) so its effectiveness is
  # questionable - but better then nothing
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
    if [ "$DEBUG" = "true" ] ; then
      echo "DEBUG - skipping ${POD_NAME} as it does not match TARGETPOD regex : ${TARGETPOD}"
    fi
    exit 0
  fi
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

# Special handling of exit code 0
if [[ "$APPLY_ON_EXITCODE_0" != "true" ]]; then
  # Check if exit code is 0, skip it
  if [[ "$TERMINATED_EXITCODE" == "0" ]]; then
    # DEBUG log the container that was skipped
    if [ "$DEBUG" = "true" ] ; then
      echo "DEBUG - skipping ${podName} with exitcode 0 ( APPLY_ON_EXITCODE_0 != true )"
    fi
    exit 0
  fi
fi

#
# We are here, lets do the termination event !
#

# Lets handle debug mode
if [ "$DEBUG" = "true" ] ; then
	echo "DEBUG - would have terminated ${POD_NAME} which completed with exitcode ${TERMINATED_EXITCODE} : ${TERMINATED_REASON}"
	exit 0
fi

# Lets perform the termination event
echo "ACTION - terminating ${POD_NAME} which completed with exitcode ${TERMINATED_EXITCODE} : ${TERMINATED_REASON}"
kubectl delete pod --wait=false $POD_NAME 

#-----------------------------------------------------------------------------------------
