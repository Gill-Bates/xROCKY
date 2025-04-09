FROM alpine:latest

# Meta information
LABEL maintainer="giiibates <pluto@krutt.org>"
LABEL description="xROCKY - A lightweight VPN with DNS blocker based on xray and blocky"

RUN apk add --no-cache \
    bash \
    curl \
    unzip \
    ca-certificates \
    iproute2 \
    net-tools \
    iputils \
    tzdata \
    tar \
    jq \
    nano \
    supervisor \
    libcap

RUN VERSION=$(curl -s https://api.github.com/repos/0xERR0R/blocky/releases/latest | grep tag_name | cut -d '"' -f 4) \
    && curl -L -o /tmp/blocky.tar.gz "https://github.com/0xERR0R/blocky/releases/download/${VERSION}/blocky_${VERSION}_Linux_x86_64.tar.gz" \
    && tar -xzf /tmp/blocky.tar.gz -C /usr/local/bin blocky \
    && chmod +x /usr/local/bin/blocky

RUN XRAY_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep tag_name | cut -d '"' -f 4) \
    && curl -L -o /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-64.zip" \
    && unzip /tmp/xray.zip xray -d /usr/local/bin/ \
    && chmod +x /usr/local/bin/xray \
    && rm -rf /tmp/xray.zip /tmp/blocky.tar.gz

# Working Directory für Blocky und Xray
WORKDIR /app

# Copy Config Files
COPY ./config/blocky.yml /app/blocky.yml
COPY ./config/xray.json /app/xray.json
COPY ./config/supervisord.conf /etc/supervisord.conf

# Copy xrocky-manager.sh
COPY xrocky-manager.sh /usr/local/bin/xrocky-manager
RUN chmod +x /usr/local/bin/xrocky-manager

# Needed for lower Ports 443 and 53
RUN setcap 'cap_net_bind_service=+ep' /usr/local/bin/xray \
    && setcap 'cap_net_bind_service=+ep' /usr/local/bin/blocky

# Expose Ports
EXPOSE 443/tcp

# Start command
CMD ["supervisord", "-c", "/etc/supervisord.conf"]
