# Community image using original OMP binary and original PinkCollab npm package.
# Not an official Docker image from either project.
FROM node:22-bookworm-slim

ARG OMP_TAG
ARG PINK_VERSION

LABEL org.opencontainers.image.title="Oh My Pi + PinkCollab for Unraid" \
      org.opencontainers.image.source="https://github.com/elmakus/pinkcollab-omp-unraid" \
      org.opencontainers.image.description="Original OMP and PinkCollab Gateway combined for Unraid" \
      org.opencontainers.image.licenses="MIT"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       bash ca-certificates curl git openssh-client ripgrep python3 \
       jq zip unzip procps tmux socat dumb-init libstdc++6 libgcc-s1 \
    && rm -rf /var/lib/apt/lists/*

# The upstream installer checks the official OMP binary's SHA-256.
ENV PI_INSTALL_DIR=/usr/local/bin
RUN test -n "$OMP_TAG" && test -n "$PINK_VERSION" \
    && curl -fsSL https://omp.sh/install -o /tmp/omp-install.sh \
    && sh /tmp/omp-install.sh --binary --ref "$OMP_TAG" \
    && rm /tmp/omp-install.sh \
    && npm install -g --no-audit --no-fund "pinkcollab@$PINK_VERSION" \
    && omp --version && pinkcollab --version

RUN useradd -m -u 1000 -s /bin/bash agent \
    && mkdir -p /workspace /home/agent/.omp /home/agent/.pinkcollab \
    && chown -R agent:agent /workspace /home/agent

COPY --chmod=755 entrypoint.sh /usr/local/bin/start-pinkcollab
ENV HOME=/home/agent
USER agent
WORKDIR /workspace
EXPOSE 8788

HEALTHCHECK --interval=30s --timeout=4s --start-period=45s --retries=3 \
  CMD node -e "require('node:http').get('http://127.0.0.1:8787/health',r=>{r.resume();process.exit(r.statusCode===200?0:1)}).on('error',()=>process.exit(1))"

ENTRYPOINT ["/usr/bin/dumb-init", "--", "/usr/local/bin/start-pinkcollab"]
