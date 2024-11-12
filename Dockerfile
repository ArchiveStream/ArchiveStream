# This is the Dockerfile for ArchiveStream, it bundles the following dependencies:
#     python3, ArchiveStream, curl, wget, git, chromium, youtube-dl, yt-dlp, single-file
# Usage:
#     git submodule update --init --recursive
#     git pull --recurse-submodules
#     docker build . -t archivestream --no-cache
#     docker run -v "$PWD/data":/data archivestream init
#     docker run -v "$PWD/data":/data archivestream add 'https://example.com'
#     docker run -v "$PWD/data":/data -it archivestream manage createsuperuser
#     docker run -v "$PWD/data":/data -p 8000:8000 archivestream server
# Multi-arch build:
#     docker buildx create --use
#     docker buildx build . --platform=linux/amd64,linux/arm64--push -t archivestream/archivestream:0.7.5 -t archivestream/archivestream:dev
#
# Read more about [developing Archivestream](https://github.com/ArchiveStream/ArchiveStream#archivestream-development).

#########################################################################################

# Use Debian 12 w/ faster package updates: https://packages.debian.org/bookworm-backports/
FROM python:3.11-slim-bookworm
# FROM debian:bookworm-backports

LABEL name="archivestream" \
    maintainer="Nick Sweeting <dockerfile@archivestream.github.io>" \
    description="All-in-one self-hosted internet archiving solution" \
    homepage="https://github.com/ArchiveStream/ArchiveStream" \
    documentation="https://github.com/ArchiveStream/ArchiveStream/wiki/Docker" \
    org.opencontainers.image.title="ArchiveStream" \
    org.opencontainers.image.vendor="ArchiveStream" \
    org.opencontainers.image.description="All-in-one self-hosted internet archiving solution" \
    org.opencontainers.image.source="https://github.com/ArchiveStream/ArchiveStream" \
    com.docker.image.source.entrypoint="Dockerfile" \
    # TODO: release ArchiveStream as a Docker Desktop extension (requires these labels):
    # https://docs.docker.com/desktop/extensions-sdk/architecture/metadata/
    com.docker.desktop.extension.api.version=">= 1.4.7" \
    com.docker.desktop.extension.icon="https://archivestream.github.io/icon.png" \
    com.docker.extension.publisher-url="https://archivestream.github.io" \
    com.docker.extension.screenshots='[{"alt": "Screenshot of Admin UI", "url": "https://github.com/ArchiveStream/ArchiveStream/assets/511499/e8e0b6f8-8fdf-4b7f-8124-c10d8699bdb2"}]' \
    com.docker.extension.detailed-description='See here for detailed documentation: https://wiki.archivestream.github.io' \
    com.docker.extension.changelog='See here for release notes: https://github.com/ArchiveStream/ArchiveStream/releases' \
    com.docker.extension.categories='database,utility-tools'

ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT

######### Environment Variables #################################

# Global system-level config
ENV TZ=UTC \
    LANGUAGE=en_US:en \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 \
    PYTHONIOENCODING=UTF-8 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    npm_config_loglevel=error

# Version config
ENV PYTHON_VERSION=3.11 \
    NODE_VERSION=22

# User config
ENV ARCHIVESTREAM_USER="archivestream" \
    DEFAULT_PUID=911 \
    DEFAULT_PGID=911 \
    IN_DOCKER=True

# Global paths
ENV CODE_DIR=/app \
    DATA_DIR=/data \
    PLAYWRIGHT_BROWSERS_PATH=/browsers
    # GLOBAL_VENV=/venv \
    # TODO: add TMP_DIR and LIB_DIR?

# Build shell config
SHELL ["/bin/bash", "-o", "pipefail", "-o", "errexit", "-o", "errtrace", "-o", "nounset", "-c"] 

######### System Environment ####################################

# Detect ArchiveStream version number by reading pyproject.toml
COPY --chown=root:root --chmod=755 pyproject.toml "$CODE_DIR/"
RUN grep '^version = ' "${CODE_DIR}/pyproject.toml" | awk -F'"' '{print $2}' > /VERSION.txt

# Force apt to leave downloaded binaries in /var/cache/apt (massively speeds up Docker builds)
RUN echo 'Binary::apt::APT::Keep-Downloaded-Packages "1";' > /etc/apt/apt.conf.d/99keep-cache \
    && echo 'APT::Install-Recommends "0";' > /etc/apt/apt.conf.d/99no-intall-recommends \
    && echo 'APT::Install-Suggests "0";' > /etc/apt/apt.conf.d/99no-intall-suggests \
    && rm -f /etc/apt/apt.conf.d/docker-clean

# Print debug info about build and save it to disk, for human eyes only, not used by anything else
RUN (echo "[i] Docker build for ArchiveStream $(cat /VERSION.txt) starting..." \
    && echo "PLATFORM=${TARGETPLATFORM} ARCH=$(uname -m) ($(uname -s) ${TARGETARCH} ${TARGETVARIANT})" \
    && echo "BUILD_START_TIME=$(date +"%Y-%m-%d %H:%M:%S %s") TZ=${TZ} LANG=${LANG}" \
    && echo \
    && echo "PYTHON=${PYTHON_VERSION} NODE=${NODE_VERSION} PATH=${PATH}" \
    && echo "CODE_DIR=${CODE_DIR} DATA_DIR=${DATA_DIR}" \
    && echo \
    && uname -a \
    && cat /etc/os-release | head -n7 \
    && which bash && bash --version | head -n1 \
    && which dpkg && dpkg --version | head -n1 \
    && echo -e '\n\n' && env && echo -e '\n\n' \
    ) | tee -a /VERSION.txt

# Create non-privileged user for archivestream and chrome
RUN echo "[*] Setting up $ARCHIVESTREAM_USER user uid=${DEFAULT_PUID}..." \
    && groupadd --system $ARCHIVESTREAM_USER \
    && useradd --system --create-home --gid $ARCHIVESTREAM_USER --groups audio,video $ARCHIVESTREAM_USER \
    && usermod -u "$DEFAULT_PUID" "$ARCHIVESTREAM_USER" \
    && groupmod -g "$DEFAULT_PGID" "$ARCHIVESTREAM_USER" \
    && echo -e "\nARCHIVESTREAM_USER=$ARCHIVESTREAM_USER PUID=$(id -u $ARCHIVESTREAM_USER) PGID=$(id -g $ARCHIVESTREAM_USER)\n\n" \
    | tee -a /VERSION.txt
    # DEFAULT_PUID and DEFAULT_PID are overriden by PUID and PGID in /bin/docker_entrypoint.sh at runtime
    # https://docs.linuxserver.io/general/understanding-puid-and-pgid

# Install system apt dependencies (adding backports to access more recent apt updates)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=apt-$TARGETARCH$TARGETVARIANT \
    echo "[+] Installing APT base system dependencies for $TARGETPLATFORM..." \
    && echo 'deb https://deb.debian.org/debian bookworm-backports main contrib non-free' > /etc/apt/sources.list.d/backports.list \
    && mkdir -p /etc/apt/keyrings \
    && apt-get update -qq \
    && apt-get install -qq -y -t bookworm-backports \
        # 1. packaging dependencies
        apt-transport-https ca-certificates apt-utils gnupg2 curl wget \
        # 2. docker and init system dependencies
        zlib1g-dev dumb-init gosu cron unzip grep dnsutils \
        # 3. frivolous CLI helpers to make debugging failed archiving easier
        tree nano iputils-ping \
        # nano iputils-ping dnsutils htop procps jq yq
    && rm -rf /var/lib/apt/lists/*

# Install sonic search backend
COPY --from=archivestream/sonic:1.4.9 /usr/local/bin/sonic /usr/local/bin/sonic
COPY --chown=root:root --chmod=755 "etc/sonic.cfg" /etc/sonic.cfg
RUN (which sonic && sonic --version) | tee -a /VERSION.txt

######### Language Environments ####################################

# Install Python environment
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=apt-$TARGETARCH$TARGETVARIANT --mount=type=cache,target=/root/.cache/pip,sharing=locked,id=pip-$TARGETARCH$TARGETVARIANT \
    echo "[+] Setting up Python $PYTHON_VERSION runtime..." \
    # NOT NEEDED because we're using a pre-built python image, keeping this here in case we switch back to custom-building our own:
    # && apt-get update -qq \
    # && apt-get install -qq -y -t bookworm-backports --no-upgrade \
    #     python${PYTHON_VERSION} python${PYTHON_VERSION}-minimal python3-pip python${PYTHON_VERSION}-venv pipx \
    # && rm -rf /var/lib/apt/lists/* \
    # tell PDM to allow using global system python site packages
    # && rm /usr/lib/python3*/EXTERNALLY-MANAGED \
    # && ln -s "$(which python${PYTHON_VERSION})" /usr/bin/python \
    # create global virtual environment GLOBAL_VENV to use (better than using pip install --global)
    # && python3 -m venv --system-site-packages --symlinks $GLOBAL_VENV \
    # && python3 -m venv --system-site-packages $GLOBAL_VENV \
    # && python3 -m venv $GLOBAL_VENV \
    # install global dependencies / python build dependencies in GLOBAL_VENV
    # && pip install --upgrade pip setuptools wheel \
    # Save version info
    && ( \
        which python3 && python3 --version | grep " $PYTHON_VERSION" \
        && which pip && pip --version \
        # && which pdm && pdm --version \
        && echo -e '\n\n' \
    ) | tee -a /VERSION.txt


# Install Node environment
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=apt-$TARGETARCH$TARGETVARIANT --mount=type=cache,target=/root/.npm,sharing=locked,id=npm-$TARGETARCH$TARGETVARIANT \
    echo "[+] Installing Node $NODE_VERSION environment..." \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_VERSION}.x nodistro main" >> /etc/apt/sources.list.d/nodejs.list \
    && curl -fsSL "https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key" | gpg --dearmor | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && apt-get update -qq \
    && apt-get install -qq -y -t bookworm-backports --no-upgrade libatomic1 \
    && apt-get install -y -t bookworm-backports --no-upgrade \
        nodejs \
    && rm -rf /var/lib/apt/lists/* \
    # Update NPM to latest version
    && npm i -g npm --cache /root/.npm \
    # Save version info
    && ( \
        which node && node --version \
        && which npm && npm --version \
        && echo -e '\n\n' \
    ) | tee -a /VERSION.txt



######### Extractor Dependencies ##################################

# Install apt dependencies
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=apt-$TARGETARCH$TARGETVARIANT --mount=type=cache,target=/root/.cache/pip,sharing=locked,id=pip-$TARGETARCH$TARGETVARIANT \
    echo "[+] Installing APT extractor dependencies globally using apt..." \
    && apt-get update -qq \
    && apt-get install -qq -y -t bookworm-backports \
        curl wget git ffmpeg ripgrep \
        # Packages we have also needed in the past:
        # youtube-dl wget2 aria2 python3-pyxattr rtmpdump libfribidi-bin mpv \
    && rm -rf /var/lib/apt/lists/* \
    # Save version info
    && ( \
        which curl && curl --version | head -n1 \
        && which wget && wget --version 2>&1 | head -n1 \
        && which git && git --version 2>&1 | head -n1 \
        && which rg && rg --version 2>&1 | head -n1 \
        && echo -e '\n\n' \
    ) | tee -a /VERSION.txt


# Install chromium browser using playwright
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=apt-$TARGETARCH$TARGETVARIANT --mount=type=cache,target=/root/.cache/pip,sharing=locked,id=pip-$TARGETARCH$TARGETVARIANT --mount=type=cache,target=/root/.cache/ms-playwright,sharing=locked,id=browsers-$TARGETARCH$TARGETVARIANT \
    echo "[+] Installing Browser binary dependencies to $PLAYWRIGHT_BROWSERS_PATH..." \
    && apt-get update -qq \
    && apt-get install -qq -y -t bookworm-backports \
        fontconfig fonts-ipafont-gothic fonts-wqy-zenhei fonts-thai-tlwg fonts-khmeros fonts-kacst fonts-symbola fonts-noto fonts-freefont-ttf \
        at-spi2-common fonts-liberation fonts-noto-color-emoji fonts-tlwg-loma-otf fonts-unifont libatk-bridge2.0-0 libatk1.0-0 libatspi2.0-0 libavahi-client3 \
        libavahi-common-data libavahi-common3 libcups2 libfontenc1 libice6 libnspr4 libnss3 libsm6 libunwind8 \
        libxaw7 libxcomposite1 libxdamage1 libxfont2 \
        libxkbfile1 libxmu6 libxpm4 libxt6 x11-xkb-utils x11-utils xfonts-encodings \
        # xfonts-scalable xfonts-utils xserver-common xvfb \
        # chrome can run without dbus/upower technically, it complains about missing dbus but should run ok anyway
        # libxss1 dbus dbus-x11 upower \
    # && service dbus start \
    # install Chromium using playwright
    && pip install playwright \
    && cp -r /root/.cache/ms-playwright "$PLAYWRIGHT_BROWSERS_PATH" \
    && playwright install chromium \
    && export CHROME_BINARY="$(python -c 'from playwright.sync_api import sync_playwright; print(sync_playwright().start().chromium.executable_path)')" \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s "$CHROME_BINARY" /usr/bin/chromium-browser \
    && mkdir -p "/home/${ARCHIVESTREAM_USER}/.config/chromium/Crash Reports/pending/" \
    && chown -R "$DEFAULT_PUID:$DEFAULT_PGID" "/home/${ARCHIVESTREAM_USER}/.config" \
    && mkdir -p "$PLAYWRIGHT_BROWSERS_PATH" \
    && chown -R $ARCHIVESTREAM_USER "$PLAYWRIGHT_BROWSERS_PATH" \
    # Save version info
    && ( \
        which chromium-browser && /usr/bin/chromium-browser --version || /usr/lib/chromium/chromium --version \
        && echo -e '\n\n' \
    ) | tee -a /VERSION.txt

# Install Node dependencies
ENV PATH="/home/$ARCHIVESTREAM_USER/.npm/bin:$PATH"
USER $ARCHIVESTREAM_USER
WORKDIR "/home/$ARCHIVESTREAM_USER/.npm"
RUN --mount=type=cache,target=/home/$ARCHIVESTREAM_USER/.npm_cache,sharing=locked,id=npm-$TARGETARCH$TARGETVARIANT,uid=$DEFAULT_PUID,gid=$DEFAULT_PGID \
    echo "[+] Installing NPM extractor dependencies in /home/$ARCHIVESTREAM_USER/.npm..." \
    && npm config set prefix "/home/$ARCHIVESTREAM_USER/.npm" \
    && npm install --global --prefer-offline --no-fund --no-audit --cache "/home/$ARCHIVESTREAM_USER/.npm_cache" \
        "@postlight/parser@^2.2.3" \
        "readability-extractor@github:ArchiveStream/readability-extractor" \
        "single-file-cli@^1.1.54" \
        "puppeteer@^23.5.0" \
        "@puppeteer/browsers@^2.4.0"
USER root
RUN ( \
        which node && node --version \
        && which npm && npm version \
        && which postlight-parser \
        && which readability-extractor && readability-extractor --version \
        && which single-file && single-file --version \
        && which puppeteer && puppeteer --version \
        && echo -e '\n\n' \
    ) | tee -a /VERSION.txt

######### Build Dependencies ####################################

# Install ArchiveStream Python dependencies
WORKDIR "$CODE_DIR"
COPY --chown=root:root --chmod=755 "./pyproject.toml" "requirements.txt" "$CODE_DIR"/
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=apt-$TARGETARCH$TARGETVARIANT --mount=type=cache,target=/root/.cache/pip,sharing=locked,id=pip-$TARGETARCH$TARGETVARIANT \
    echo "[+] Installing PIP ArchiveStream dependencies from requirements.txt for ${TARGETPLATFORM}..." \
    && apt-get update -qq \
    && apt-get install -qq -y -t bookworm-backports \
        build-essential gcc \
        libssl-dev libldap2-dev libsasl2-dev \
        python3-ldap python3-msgpack python3-mutagen python3-regex python3-pycryptodome procps \
        pipx \
    # && ln -s "$GLOBAL_VENV" "$APP_VENV" \
    # && pdm use --venv in-project \
    # && pdm run python -m ensurepip \
    # && pdm sync --fail-fast --no-editable --group :all --no-self \
    # && pdm export -o requirements.txt --without-hashes \
    # && source $GLOBAL_VENV/bin/activate \
    && pip install -r requirements.txt \
    && apt-get purge -y \
        build-essential gcc \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Install ArchiveStream Python package from source
COPY --chown=root:root --chmod=755 "." "$CODE_DIR/"
RUN --mount=type=cache,target=/root/.cache/pip,sharing=locked,id=pip-$TARGETARCH$TARGETVARIANT \
    echo "[*] Installing PIP ArchiveStream package from $CODE_DIR..." \
    && pip install -e "${CODE_DIR}[all]" \
    && rm -rf /var/lib/apt/lists/*

####################################################

# Setup ArchiveStream runtime config
WORKDIR "$DATA_DIR"
RUN openssl rand -hex 16 > /etc/machine-id \
    && mkdir -p "/tmp/archivestream" \
    && chown -R "$DEFAULT_PUID:$DEFAULT_PGID" "/tmp/archivestream" \
    && mkdir -p "/usr/share/archivestream/lib" \
    && chown -R "$DEFAULT_PUID:$DEFAULT_PGID" "/usr/share/archivestream/lib"

ENV GOOGLE_API_KEY=no \
    GOOGLE_DEFAULT_CLIENT_ID=no \
    GOOGLE_DEFAULT_CLIENT_SECRET=no \
    TMP_DIR=/tmp/archivestream \
    LIB_DIR=/usr/share/archivestream/lib \
    ALLOWED_HOSTS=*

# Print version for nice docker finish summary
RUN (echo -e "\n\n[√] Finished Docker build succesfully. Saving build summary in: /VERSION.txt" \
    && echo -e "PLATFORM=${TARGETPLATFORM} ARCH=$(uname -m) ($(uname -s) ${TARGETARCH} ${TARGETVARIANT})\n" \
    && echo -e "BUILD_END_TIME=$(date +"%Y-%m-%d %H:%M:%S %s")\n\n" \
    ) | tee -a /VERSION.txt
RUN "$CODE_DIR"/bin/docker_entrypoint.sh version 2>&1 | tee -a /VERSION.txt

####################################################

# Open up the interfaces to the outside world
WORKDIR "$DATA_DIR"
VOLUME "$DATA_DIR"
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=20s --retries=15 \
    CMD curl --silent 'http://localhost:8000/health/' | grep -q 'OK'

ENTRYPOINT ["dumb-init", "--", "/app/bin/docker_entrypoint.sh"]
CMD ["archivestream", "server", "--quick-init", "0.0.0.0:8000"]
