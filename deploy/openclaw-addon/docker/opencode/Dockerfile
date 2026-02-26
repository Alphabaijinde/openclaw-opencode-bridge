FROM debian:bookworm-slim

ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY

ENV HTTP_PROXY=${HTTP_PROXY}
ENV HTTPS_PROXY=${HTTPS_PROXY}
ENV NO_PROXY=${NO_PROXY}
ENV http_proxy=${HTTP_PROXY}
ENV https_proxy=${HTTPS_PROXY}
ENV no_proxy=${NO_PROXY}

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates git \
  && rm -rf /var/lib/apt/lists/*

# Copy the locally installed opencode binary into the image.
# Prepare it with:
#   cp ~/.opencode/bin/opencode ./docker/opencode/opencode
COPY opencode /usr/local/bin/opencode
RUN chmod +x /usr/local/bin/opencode

WORKDIR /workspace

EXPOSE 4096

ENTRYPOINT ["/usr/local/bin/opencode"]
CMD ["serve", "--hostname", "0.0.0.0", "--port", "4096"]
