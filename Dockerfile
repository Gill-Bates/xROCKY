FROM alpine:latest

LABEL maintainer="giiibates <xrocky@stronzi.org>"
LABEL description="xROCKY - A lightweight VPN with DNS blocker based on Xray and Blocky"

# Install system packages
RUN apk add --no-cache \
    bash \
    curl \
    unzip \
    ca-certificates \
    iproute2 \
    net-tools \
    logrotate \
    cronie \
    iputils \
    tzdata \
    tar \
    jq \
    nano \
    supervisor \
    libcap

# Install Blocky (latest release)
RUN VERSION=$(curl -s https://api.github.com/repos/0xERR0R/blocky/releases/latest | grep tag_name | cut -d '"' -f 4) \
    && curl -L -o /tmp/blocky.tar.gz "https://github.com/0xERR0R/blocky/releases/download/${VERSION}/blocky_${VERSION}_Linux_x86_64.tar.gz" \
    && tar -xzf /tmp/blocky.tar.gz -C /usr/local/bin blocky \
    && chmod +x /usr/local/bin/blocky

# Install Xray (latest release)
RUN XRAY_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep tag_name | cut -d '"' -f 4) \
    && curl -L -o /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-64.zip" \
    && unzip /tmp/xray.zip xray -d /usr/local/bin/ \
    && chmod +x /usr/local/bin/xray \
    && rm -rf /tmp/*

# Install Cronie
RUN mkdir -p /var/spool/cron/crontabs \
    && touch /etc/crontabs/root \
    && chmod 600 /etc/crontabs/root \
    && printf "0 0 * * * /usr/sbin/logrotate /etc/logrotate.conf\n" > /etc/crontabs/root

# Create working directory
WORKDIR /app

# Copy config files
COPY ./config/blocky.yml /app/blocky.yml
COPY ./config/xray.json /app/xray.json
COPY ./config/supervisord.conf /etc/supervisord.conf
COPY ./config/logrotate /etc/logrotate.d/xrocky
COPY ./config/logrotate.conf /etc/logrotate.conf
COPY ./scripts/xrocky-manager.sh /usr/local/bin/xrocky-manager
COPY ./scripts/entrypoint.sh /usr/local/bin/xrocky-entrypoint

# Allow Blocky and Xray to bind to privileged ports
RUN setcap 'cap_net_bind_service=+ep' /usr/local/bin/xray \
    && setcap 'cap_net_bind_service=+ep' /usr/local/bin/blocky \
    && chmod +x /usr/local/bin/xrocky-entrypoint /usr/local/bin/xrocky-manager

# Expose needed ports
EXPOSE 443/tcp
EXPOSE 53/udp

# Start everything via supervisord
CMD ["supervisord", "-c", "/etc/supervisord.conf"]
