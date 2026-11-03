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

# Orca headless runtime: fixed upstream version and verified upstream .deb checksum.
# Extract instead of installing the .deb: keep the same non-root user and Docker process manager.
ARG ORCA_VERSION=1.4.247
ARG ORCA_SHA256=7e2c0c879beadd225c48b8d55774cef48b65f9b29ea46c9066db8d204e93e7d1
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgtk-3-0 libnotify4 libnss3 libxss1 libxtst6 xdg-utils \
    libatspi2.0-0 libuuid1 libsecret-1-0 libasound2 libgbm1 \
    python3-gi gir1.2-atspi-2.0 at-spi2-core xdotool xclip xvfb supervisor \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fL --retry 3 --connect-timeout 20 \
    -o /tmp/orca.deb \
    "https://github.com/stablyai/orca/releases/download/v${ORCA_VERSION}/orca-ide_${ORCA_VERSION}_amd64.deb" \
    && echo "${ORCA_SHA256}  /tmp/orca.deb" | sha256sum -c - \
    && dpkg-deb -x /tmp/orca.deb / \
    && rm /tmp/orca.deb \
    && ln -s /opt/Orca/resources/bin/orca-ide /usr/local/bin/orca-ide \
    && /usr/local/bin/orca-ide --version

# node:22 already includes user "node" with UID/GID 1000.
# Rename it to keep the Unraid appdata paths and user consistent.
RUN usermod -l agent -d /home/agent -m node \
    && groupmod -n agent node \
    && mkdir -p /workspace /home/agent/.omp /home/agent/.pinkcollab \
    && chown -R agent:agent /workspace /home/agent

COPY --chmod=755 entrypoint.sh /usr/local/bin/start-pinkcollab
COPY --chmod=755 start-orca.sh /usr/local/bin/start-orca-server
COPY --chmod=644 supervisord.conf /etc/supervisor/supervisord.conf
COPY --chmod=644 healthcheck.js /usr/local/bin/healthcheck.js
# Persist user-installed programs and CLI credentials across Unraid image updates.
# System packages (apt) remain managed by Dockerfile builds.
ENV HOME=/home/agent \
    NPM_CONFIG_PREFIX=/home/agent/.local/npm \
    GIT_CONFIG_GLOBAL=/home/agent/.config/gitconfig \
    PATH=/home/agent/.local/bin:/home/agent/.local/npm/bin:$PATH
USER agent
WORKDIR /workspace
EXPOSE 8788 6768

HEALTHCHECK --interval=30s --timeout=6s --start-period=90s --retries=3 \
  CMD ["node", "/usr/local/bin/healthcheck.js"]

ENTRYPOINT ["/usr/bin/dumb-init", "--", "/usr/local/bin/start-pinkcollab"]
