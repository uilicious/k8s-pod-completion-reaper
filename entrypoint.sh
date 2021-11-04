#!/bin/bash

if [ -z "$NAMESPACE" ]
then
      echo "# [CRITICAL-ISSUE] Missing required 'NAMESPACE' environment variable"
      exit 1
fi

if [ -z "$TARGET_POD" ]
then
      echo "# [WARNING] Missing required 'TARGETPOD' environment variable - this will match against all pods in the namespace"
fi

# Startup the shell operator
/shell-operator start