#!/bin/bash

if [ -z "$NAMESPACE" ]
then
      echo "# [CRITICAL-ISSUE] Missing required 'NAMESPACE' environment variable"
      exit 1
fi

if [ -z "$TARGET_POD" ]
then
      echo "# [CRITICAL-ISSUE] Missing required 'TARGETPOD' environment variable"
      exit 1
fi

# Startup the shell operator
/shell-operator start