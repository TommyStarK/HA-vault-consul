FROM consul:latest
COPY ./consul_agent_startup.sh /
COPY ./agent/server/config.json /consul/config_template.json
RUN apk update && \
    apk add bash && \
    chmod +x /consul_agent_startup.sh
CMD ["/bin/bash", "/consul_agent_startup.sh"]
