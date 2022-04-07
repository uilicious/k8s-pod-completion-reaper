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
else
# Get the raw JSON event string, we intentionally do this only once
# to reduce the amount of IO involved in temporary files
JSON_EVENT_STR=$(cat ${BINDING_CONTEXT_PATH})

#Can't check if enabled earlier in code because hooks need at least have one property
# Get the JSON object
JSON_OBJ_STR=$(echo $JSON_EVENT_STR | jq -r '.[0].object')
# Lets extract out several key values
POD_NAME=$(echo "$JSON_OBJ_STR" | jq -r '.metadata.name')
fi
