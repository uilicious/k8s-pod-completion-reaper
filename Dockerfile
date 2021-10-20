FROM flant/shell-operator:latest
ADD hooks /hooks
RUN chmod 755 /hooks/*.sh && chmod +x /hooks/*.sh