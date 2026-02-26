FROM debian:bookworm-slim

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
