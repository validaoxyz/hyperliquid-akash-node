#!/usr/bin/env bash
set -euo pipefail

# Start cron for pruning in background
cron

# Generate override gossip config
python3 /usr/local/bin/generate_gossip_config.py

# Run visor directly (running as root inside container is acceptable and avoids duplicate processes under Rosetta)
exec gosu hluser /home/hluser/hl-visor run-non-validator --replica-cmds-style recent-actions --serve-evm-rpc 