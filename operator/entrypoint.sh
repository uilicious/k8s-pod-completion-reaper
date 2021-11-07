#!/bin/bash

#
# ENV variables safety check
#
if [ -z "$NAMESPACE" ]
then
      echo "# [CRITICAL-ISSUE] Missing required 'NAMESPACE' environment variable"
      exit 1
fi
if [ -z "$TARGETPOD" ]
then
      echo "# [WARNING] Missing required 'TARGETPOD' environment variable - this will match against all pods in the namespace"
fi

# Startup the shell operator
if [[ "$KUBECTL_FALLBACK_ENABLE" == "true" ]]; then
      /operator/kubectl-fallback.sh &
fi

# Startup the shell operator
if [[ "$SHELL_OPERATOR_ENABLE" == "true" ]]; then
      /shell-operator start &
fi

# Wait for everything to finish, before terminating the process
wait