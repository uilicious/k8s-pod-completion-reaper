FROM flant/shell-operator:latest

# Adding alpine coreutils, this is required for some bash script utilities
# like the date command to work as expected
RUN apk add --update coreutils

# Add the pods-hook file, and entrypoint script
ADD hooks /hooks
ADD operator /operator
RUN chmod 755 /hooks/*.sh && chmod +x /hooks/*.sh && \
    chmod 755 /operator/*.sh && chmod +x /operator/*.sh

# Trigger the entrypoint script
ENTRYPOINT ["/sbin/tini", "--", "/operator/entrypoint.sh"]
CMD []

#
# Environment variables for usage
#
# This is required
#
ENV NAMESPACE=""

#
# Regex rule, for matching against pod names
# Which the termination action will be limited to
#
# This is optional
#
ENV TARGETPOD=""

#
# Perform termination of pods even if they exited
# with an exit code of 0
#
# default="true"
#
ENV APPLY_ON_EXITCODE_0="true"

#
# DEBUG mode, when enabled, performs no actions and only does logging
#
# default="false"
#
ENV DEBUG="false"

#
# Delegate hook stdout/ stderr JSON logging to the hooks
# and act as a proxy that adds some extra fields before just printing the output.
# NOTE: It ignores LOG_TYPE for the output of the hooks; 
# expects JSON lines to stdout/ stderr from the hooks
#
# Doesn't seem to work ? See link below
# https://github.com/flant/shell-operator/pull/383
#
ENV LOG_PROXY_HOOK_JSON="false"

#
# Logging formatter type: json, text or color.
#
# default is json
#
ENV LOG_TYPE="text"

#
# Disable timestamp logging if flag is present.
# Useful when output is redirected to logging system that already adds timestamps.
#
# default = "false"
#
ENV LOG_NO_TIME="true"

#
# LOG_LEVEL for the shell-operator, use either
# debug, info, error
#
# default="info"
#
ENV LOG_LEVEL="error"

#
# Enable the use of the main shell-operator workflow
# This helps react to event quicker in a "live" manner for pod completion events, 
# however seems to sometimes "miss" event based on our observations in the field.
#
# default="true"
#
ENV SHELL_OPERATOR_ENABLE="true"

#
# Enable the inbuilt kubectl fallback behaviour
# This uses kubectl on a polling basis, to apply the pod reaper rules
# as such, it may potentially be delayed by the "polling interval" setting.
#
# This also introduces some advance behaviour, like terminating unhealthy nodes
#
# default="true"
#
ENV KUBECTL_FALLBACK_ENABLE="true"

#
# Polling interval to wait bewtween scans, note that actual interval
# maybe significant longer if the kubectl commands are "slow"
#
# default="30s"
#
ENV KUBECTL_POLLING_INTERVAL="30s"

#
# Delay interval between pods, this help prevents the entire cluster from being deleted
# and restarting at the same time, putting an excess strain on the scheduler
#
# default="10s"
#
ENV KUBECTL_POD_DELETION_WAIT="10s"

#
# Limit the termination of unhealthy nodes to be older then the stated time in minutes
#
# Minimum age is used to work around race conditions, where a pod is "unhealthy" at start
#
# default="5"
#
ENV KUBECTL_MIN_AGE_IN_MINUTES="5"

#
# Pre-emptively perform pod termination on unhealthy nodes older thant the stated min age
# this helps quicken the overal pod termination, and replacement process.
# 
# default="false"
#
ENV KUBECTL_APPLY_ON_UNHEALTHY_NODES="false"
