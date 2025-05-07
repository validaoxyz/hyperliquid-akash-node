FROM ubuntu:24.04

ARG USERNAME=hluser
ARG USER_UID=10000
ARG USER_GID=$USER_UID

# Define URLs as environment variables
ARG PUB_KEY_URL=https://raw.githubusercontent.com/hyperliquid-dex/node/refs/heads/main/pub_key.asc
ARG HL_VISOR_URL=https://binaries.hyperliquid.xyz/Mainnet/hl-visor
ARG HL_VISOR_ASC_URL=https://binaries.hyperliquid.xyz/Mainnet/hl-visor.asc

# Create user and install dependencies
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update -y && apt-get install -y curl gnupg python3 cron gosu jq \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /home/$USERNAME/hl/data && chown -R $USERNAME:$USERNAME /home/$USERNAME/hl

# Install tcping static binary (amd64)
ARG TCPING_VERSION=v2.7.1
RUN curl -L -o /tmp/tcping.deb "https://github.com/pouriyajamshidi/tcping/releases/download/${TCPING_VERSION}/tcping-amd64.deb" \
    && dpkg -i /tmp/tcping.deb \
    && rm /tmp/tcping.deb

WORKDIR /home/$USERNAME

# Configure chain to Mainnet (can be overridden by CHAIN env at runtime)
RUN echo '{"chain": "Mainnet"}' > /home/$USERNAME/visor.json

# Import GPG public key
RUN curl -o /home/$USERNAME/pub_key.asc $PUB_KEY_URL \
    && gpg --import /home/$USERNAME/pub_key.asc \
    && mkdir -p /home/$USERNAME/.gnupg \
    && cp -r /root/.gnupg/* /home/$USERNAME/.gnupg/ \
    && chown -R $USERNAME:$USERNAME /home/$USERNAME/.gnupg

# Download and verify hl-visor binary
RUN curl -o /home/$USERNAME/hl-visor $HL_VISOR_URL \
    && curl -o /home/$USERNAME/hl-visor.asc $HL_VISOR_ASC_URL \
    && gpg --verify /home/$USERNAME/hl-visor.asc /home/$USERNAME/hl-visor \
    && chmod +x /home/$USERNAME/hl-visor

# Expose gossip ports
EXPOSE 4000-4010

# -------------------- Custom helper & pruning -------------------- #
# Copy README (for seed peer extraction)
COPY README.md /app/README.md
ENV README_PATH=/app/README.md

# Helper & pruning scripts
COPY generate_gossip_config.py /usr/local/bin/generate_gossip_config.py
COPY pruner/scripts/ /home/$USERNAME/scripts/
COPY pruner/cron/cron.d/prune /etc/cron.d/prune
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /usr/local/bin/generate_gossip_config.py /entrypoint.sh /home/$USERNAME/scripts/*.sh \
    && chmod 0644 /etc/cron.d/prune \
    && chown -R $USERNAME:$USERNAME /home/$USERNAME/scripts

# Ensure cron job file is registered
RUN crontab /etc/cron.d/prune

# Use root for cron startup, but entrypoint will drop privileges for visor process
USER root

# Replace entrypoint to start cron, generate gossip config, and run visor
ENTRYPOINT ["/entrypoint.sh"]
