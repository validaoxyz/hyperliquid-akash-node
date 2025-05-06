#!/usr/bin/env bash
set -euo pipefail

# Start cron for pruning in background
cron

# Generate override gossip config
python3 /usr/local/bin/generate_gossip_config.py

# Drop privileges to hluser then exec visor
exec su -s /bin/bash hluser -c "/home/hluser/hl-visor run-non-validator --replica-cmds-style recent-actions --serve-eth-rpc" 