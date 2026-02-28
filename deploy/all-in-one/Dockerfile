FROM ghcr.io/openclaw/openclaw:latest

ARG OPENCODE_NPM_VERSION=1.1.51
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY

USER root

ENV HTTP_PROXY=${HTTP_PROXY}
ENV HTTPS_PROXY=${HTTPS_PROXY}
ENV NO_PROXY=${NO_PROXY}
ENV http_proxy=${HTTP_PROXY}
ENV https_proxy=${HTTPS_PROXY}
ENV no_proxy=${NO_PROXY}

RUN npm install -g "opencode-ai@${OPENCODE_NPM_VERSION}" \
  && opencode --version

WORKDIR /opt/openclaw-opencode-bridge

COPY --chown=node:node package.json ./
COPY --chown=node:node server.mjs ./
COPY --chown=node:node deploy/all-in-one/entrypoint.sh /usr/local/bin/openclaw-opencode-all-in-one

RUN chmod 755 /usr/local/bin/openclaw-opencode-all-in-one \
  && mkdir -p /var/lib/openclaw-opencode \
  && chown -R node:node /var/lib/openclaw-opencode

ENV OPENCLAW_STACK_DIR=/var/lib/openclaw-opencode

EXPOSE 18789 18790 8787

USER node

ENTRYPOINT ["/usr/local/bin/openclaw-opencode-all-in-one"]
