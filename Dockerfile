# Community image using original OMP binary and original PinkCollab npm package.
# Not an official Docker image from either project.
FROM node:22-bookworm-slim

ARG OMP_TAG
ARG PINK_VERSION
ARG BUN_VERSION=1.4.4

LABEL org.opencontainers.image.title="Oh My Pi + PinkCollab for Unraid" \
      org.opencontainers.image.source="https://github.com/elmakus/pinkcollab-omp-unraid" \
      org.opencontainers.image.description="Original OMP and PinkCollab Gateway combined for Unraid" \
      org.opencontainers.image.licenses="MIT"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       bash ca-certificates curl git openssh-client ripgrep python3 \
       python3-venv python3-pip python3-dev build-essential pkg-config libssl-dev \
       fd-find sqlite3 gh rsync iproute2 iputils-ping dnsutils netcat-openbsd \
       jq zip unzip procps tmux socat dumb-init libstdc++6 libgcc-s1 \
       less nano wget \
    && ln -s /usr/bin/fdfind /usr/local/bin/fd \
    && rm -rf /var/lib/apt/lists/*

# The upstream installer checks the official OMP binary's SHA-256.
ENV PI_INSTALL_DIR=/usr/local/bin \
    BUN_INSTALL=/opt/bun \
    PATH=/opt/bun/bin:$PATH

# Bun is useful for TypeScript extensions, scripts and third-party tooling.
# OMP itself still uses the official, SHA-verified standalone binary.
RUN curl -fsSL https://bun.sh/install | bash -s "bun-v${BUN_VERSION}" \
    && bun --version
RUN test -n "$OMP_TAG" && test -n "$PINK_VERSION" \
    && curl -fsSL https://omp.sh/install -o /tmp/omp-install.sh \
    && sh /tmp/omp-install.sh --binary --ref "$OMP_TAG" \
    && rm /tmp/omp-install.sh \
    && npm install -g --no-audit --no-fund \
         "pinkcollab@$PINK_VERSION" \
         typescript typescript-language-server pyright \
         yaml-language-server bash-language-server \
         dockerfile-language-server-nodejs \
    && omp --version && pinkcollab --version \
    && command -v bun && command -v gh && command -v fd \
    && command -v typescript-language-server \
    && command -v pyright-langserver \
    && command -v yaml-language-server \
    && command -v bash-language-server \
    && command -v docker-langserver

# node:22 already includes user "node" with UID/GID 1000.
# Rename it to keep the Unraid appdata paths and user consistent.
RUN usermod -l agent -d /home/agent -m node \
    && groupmod -n agent node \
    && mkdir -p /workspace /home/agent/.omp /home/agent/.pinkcollab \
    && chown -R agent:agent /workspace /home/agent

COPY --chmod=755 entrypoint.sh /usr/local/bin/start-pinkcollab
# Persist user-installed programs and CLI credentials across Unraid image updates.
# System packages (apt) remain managed by Dockerfile builds.
ENV HOME=/home/agent \
    NPM_CONFIG_PREFIX=/home/agent/.local/npm \
    GIT_CONFIG_GLOBAL=/home/agent/.config/gitconfig \
    PATH=/home/agent/.local/bin:/home/agent/.local/npm/bin:$PATH
USER agent
WORKDIR /workspace
EXPOSE 8788

HEALTHCHECK --interval=30s --timeout=4s --start-period=45s --retries=3 \
  CMD node -e "require('node:http').get('http://127.0.0.1:8787/health',r=>{r.resume();process.exit(r.statusCode===200?0:1)}).on('error',()=>process.exit(1))"

ENTRYPOINT ["/usr/bin/dumb-init", "--", "/usr/local/bin/start-pinkcollab"]
