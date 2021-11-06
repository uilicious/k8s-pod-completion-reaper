#!/bin/bash

################################################################################################################
#
# To import / use the respective function simply
#
# ```
# source /operator/kubectl-helper-lib.sh
# ```
#
################################################################################################################

# Boolean flag to indicate that the script is executed as the kubectl operator
IS_KUBECTL_OPERATOR="false"

#
# Given the POD_FULLNAME passed as the first argument $1
# and the TERMINATION_REASON as argument $2
#
# terminate it (unless DEBUG=true)
#
function DELETE_POD_CMD {
    # Operator mode
    if [[ "$IS_KUBECTL_OPERATOR" == "true" ]]; then
        OPERATOR_TYPE="kubectl-fallback"
    else
        OPERATOR_TYPE="shell-operator"
    fi
    
    # Lets handle debug mode
    if [[ "$DEBUG" == "true" ]]; then
        echo "[DEBUG:$OPERATOR_TYPE] - would have terminated $1 - $2"
        return 0
    fi

    # Lets perform the termination event
    echo "[ACTION:$OPERATOR_TYPE] - terminating $1 - $2"
    kubectl delete pod --wait=false $1

    # Perform any wait if needed
    if [[ "$IS_KUBECTL_OPERATOR" == "true" ]]; then
        sleep "$KUBECTL_POD_DELETION_WAIT"
    fi
}

#
# POD function, which works on a single POD_OBJ_JSON
# and handle any, if required, terminations via kubectl
#

# The function itself to call
function PROCESS_POD_OBJ_JSON {
    # Operator mode
    if [[ "$IS_KUBECTL_OPERATOR" == "true" ]]; then
        OPERATOR_TYPE="kubectl-fallback"
    else
        OPERATOR_TYPE="shell-operator"
    fi
    
    # Get the POD_OBJ_JSON
    POD_OBJ_JSON="$1"
        
    # Lets extract out the podname
    POD_FULLNAME=$(echo "$POD_OBJ_JSON" | jq -r '.metadata.name')

    # Skip if null
    if [[ -z "$POD_FULLNAME" ]] || [[ "$POD_FULLNAME" == "null" ]]; then
        return 0
    fi

    # Lets skip the pods whose names do not match
    if [[ -z "$TARGETPOD" ]]; then
        # TARGETPOD parameter is empty, match all containers in namespace
        # : Does nothing
        :
    else
        if [[ "$POD_FULLNAME" =~ "$TARGETPOD" ]]; then
            # TARGETPOD matches, we shall permit this event
            # : Does nothing
            :
        else
            # TARGETPOD does not match, we should skip this event
            if [[ "$DEBUG" == "true" ]]; then
                echo "[DEBUG:$OPERATOR_TYPE] - skipping ${POD_FULLNAME} as it does not match TARGETPOD regex : $TARGETPOD"
            fi
            return 0
        fi
    fi

    # Lets get the pod start time
    POD_START_DATETIME=$(echo "$POD_OBJ_JSON" | jq -r '.status.startTime')

    # Lets skip pod who does not have a start datetime (not eligible for termination)
    # Skip if null
    if [[ -z "$POD_START_DATETIME" ]] || [[ "$POD_START_DATETIME" == "null" ]]; then
        return 0
    fi

    ##
    ## Perform kubectl operator specific checks
    ## 

    if [[ "$IS_KUBECTL_OPERATOR" == "true" ]]; then
        ##
        ## Check if the pod is eligible for processing
        ##

        # Lets get the start timestamp
        POD_START_TIME=$(date --date "$POD_START_DATETIME" +'%s')

        # Lets get the threshold timestamp
        THRESHOLD_TIME=$(date --date "$KUBECTL_MIN_AGE_IN_MINUTES minutes ago" +'%s')

        # Lets skip the POD, if its newer (younger) then the threshold time
        if [[ "$POD_START_TIME" -gt "$THRESHOLD_TIME" ]]; then
            if [[ "$DEBUG" == "true" ]]; then
                echo "[DEBUG:$OPERATOR_TYPE] - skipping ${POD_FULLNAME} as its newer then KUBECTL_MIN_AGE_IN_MINUTES"
            fi
            return 0;
        fi

        ##
        ## Terminate because of restart count
        ## 

        # Lets check if there was a restart previously, and terminate it 
        RESTART_COUNT=$(echo "$POD_OBJ_JSON" | jq -r '.status.containerStatuses[0].restartCount')

        # Handle termination based on RESTART_COUNT
        if [[ "$RESTART_COUNT" -gt "0" ]]; then
            # Lets restart and terminate
            DELETE_POD_CMD "$POD_FULLNAME" "it has restarted $RESTART_COUNT times previously"
            return 0
        fi

        ##
        ## Terminate because of failed healthcheck
        ## 
        
        if [[ "$KUBECTL_APPLY_ON_UNHEALTHY_NODES" == "true" ]]; then
            STARTED_STATUS=$(echo "$POD_OBJ_JSON" | jq -r '.status.containerStatuses[0].started')
            READY_STATUS=$(echo "$POD_OBJ_JSON" | jq -r '.status.containerStatuses[0].ready')

            # Terminate any container in "unhealthy" state
            if [[ "$STARTED_STATUS" == "true" ]]; then
                if [[ "$READY_STATUS" == "false" ]]; then
                    DELETE_POD_CMD "$POD_FULLNAME" "due to lack of ready ($READY_STATUS) status"
                    return 0
                fi
            fi
        fi
        
    fi

    ##
    ## Terminate because of exit code
    ## 

    # Get the terminated exit code and reason
    TERMINATED_EXITCODE=$(echo "$POD_OBJ_JSON" | jq -r '.status.containerStatuses[0].state.terminated.exitCode')
    TERMINATED_REASON=$(echo "$POD_OBJ_JSON" | jq -r '.status.containerStatuses[0].state.terminated.reason')

    # Fallback to "lastState", this can happen if the contianer is started "quickly"
    # before the event is properlly handled - and/or - the original event was missed
    if [[ -z "$TERMINATED_EXITCODE" ]] || [[ "$TERMINATED_EXITCODE" == "null" ]]; then
        TERMINATED_EXITCODE=$(echo "$POD_OBJ_JSON" | jq -r '.status.containerStatuses[0].lastState.terminated.exitCode')
        TERMINATED_REASON=$(echo "$POD_OBJ_JSON" | jq -r '.status.containerStatuses[0].lastState.terminated.reason')
    fi

    # If there is no exitcode / reason, we presume its a misfied event
    # so we shall ignore it
    if [[ -z "$TERMINATED_EXITCODE" ]] || [[ "$TERMINATED_EXITCODE" == "null" ]]; then
        return 0
    fi

    # Special handling of exit code 0
    if [[ "$APPLY_ON_EXITCODE_0" != "true" ]]; then
        # Check if exit code is 0, skip it
        if [[ "$TERMINATED_EXITCODE" == "0" ]]; then
            # DEBUG log the container that was skipped
            if [[ "$DEBUG" == "true" ]]; then
                echo "[DEBUG:$OPERATOR_TYPE] - skipping ${podName} with exitcode 0 ( APPLY_ON_EXITCODE_0 != true )"
            fi
            return 0
        fi
    fi

    #
    # We are here, lets do the termination event !
    #
    DELETE_POD_CMD "$POD_FULLNAME" "completed with exitcode $TERMINATED_EXITCODE : $TERMINATED_REASON"
}

#
# POD function, which works on a list of POD_OBJ_LIST_JSON
# and handle any, if required, terminations via kubectl
#

# The function itself to call
function PROCESS_POD_OBJ_LIST_JSON {
    # Lets iterate each object until a null occurs
    # this works around the lack of "length" parameter to iterate on
    POD_OBJ_LIST_JSON="$1"

    # Idx of the object
    IDX="0"

    # Get the first object
    POD_OBJ_JSON=$(echo "$POD_OBJ_LIST_JSON" | jq ".[$IDX]")

    # The bash loop
    while [[ "$POD_OBJ_JSON" != "null" ]]; do
        # Process the pod obj
        PROCESS_POD_OBJ_JSON "$POD_OBJ_JSON"

        # And increment
        IDX=$((IDX+1))
        POD_OBJ_JSON=$(echo "$POD_OBJ_LIST_JSON" | jq ".[$IDX]")
    done
}

#
# Runs a single session of the kubectl operator
# this is meant to run in a larger loop
#
function PROCESS_KUBECTL_OPERATOR {

    # Configure the kubectl operator
    export IS_KUBECTL_OPERATOR="true"

    # Get the pod object list
    POD_OBJ_LIST_JSON=$(kubectl get pods --namespace="$NAMESPACE" -o json | jq -r '.items')

    # And process it, see kubectl-helper-lib.sh for the function
    PROCESS_POD_OBJ_LIST_JSON "$POD_OBJ_LIST_JSON"
}