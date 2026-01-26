FROM debian:bookworm-slim

# OCI-konforme Labels
LABEL org.opencontainers.image.title="xROCKY"
LABEL org.opencontainers.image.description="A lightweight VPN with DNS blocker based on Xray and Blocky"
LABEL org.opencontainers.image.authors="giiibates <xrocky@stronzi.org>"
LABEL org.opencontainers.image.source="https://github.com/giiibates/xROCKY"
LABEL org.opencontainers.image.licenses="MIT"

# Gepinnte Versionen für Reproduzierbarkeit
ARG BLOCKY_VERSION=v0.28.2
ARG XRAY_VERSION=v26.1.23

# Install system packages (minimiert für Produktion)
# Hinweis: nano, net-tools, procps, iputils-ping für Debug entfernt
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends --no-install-suggests \
    bash \
    ca-certificates \
    curl \
    dos2unix \
    iproute2 \
    jq \
    libcap2-bin \
    qrencode \
    supervisor \
    tar \
    tzdata \
    unzip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Blocky (gepinnte Version, robustes curl)
RUN curl -fsSL -o /tmp/blocky.tar.gz \
    "https://github.com/0xERR0R/blocky/releases/download/${BLOCKY_VERSION}/blocky_${BLOCKY_VERSION}_Linux_x86_64.tar.gz" \
    && tar -xzf /tmp/blocky.tar.gz -C /usr/local/bin blocky \
    && chmod +x /usr/local/bin/blocky \
    && rm -rf /tmp/*

# Install Xray (gepinnte Version, robustes curl)
RUN curl -fsSL -o /tmp/xray.zip \
    "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-64.zip" \
    && unzip /tmp/xray.zip xray -d /usr/local/bin/ \
    && chmod +x /usr/local/bin/xray \
    && rm -rf /tmp/*

# Create working directory
WORKDIR /app

# Copy config files (neue Pfade: app/)
COPY ./app/config/blocky.yml /app/blocky.yml
COPY ./app/config/xray.json /app/xray.json
COPY ./app/config/supervisord.conf /etc/supervisor/supervisord.conf
COPY ./app/scripts/xrocky-manager.sh /usr/local/bin/xrocky-manager
COPY ./app/scripts/entrypoint.sh /usr/local/bin/xrocky-entrypoint

# Allow Blocky and Xray to bind to privileged ports
# Hinweis: Container läuft als root, da DNS (Port 53) und raw sockets benötigt werden
RUN setcap 'cap_net_bind_service=+ep' /usr/local/bin/xray && \
    setcap 'cap_net_bind_service=+ep' /usr/local/bin/blocky && \
    chmod +x /usr/local/bin/xrocky-entrypoint /usr/local/bin/xrocky-manager

RUN dos2unix /usr/local/bin/xrocky-manager \
    /usr/local/bin/xrocky-entrypoint \
    /etc/supervisor/supervisord.conf

# Expose needed ports
# DNS: UDP und TCP (für große Antworten / Fallback)
# HTTPS: für Xray VLESS/VMess
EXPOSE 443/tcp
EXPOSE 53/udp
EXPOSE 53/tcp

# Entrypoint für Initialisierung, CMD für Supervisor
ENTRYPOINT ["/usr/local/bin/xrocky-entrypoint"]
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
