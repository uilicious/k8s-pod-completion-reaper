FROM flant/shell-operator:latest

# Add the pods-hook file, and entrypoint script
ADD hooks /hooks
ADD entrypoint.sh /entrypoint.sh
RUN chmod 755 /hooks/*.sh && chmod +x /hooks/*.sh

# Trigger the entrypoint script
ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]
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
# This is required
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
# LOG_LEVEL for the shell-operator, use either
# debug, info, error
#
# default="error"
#
ENV LOG_LEVEL="error"