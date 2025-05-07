#!/usr/bin/env bash
set -euo pipefail

# Start cron for pruning in background
cron

# Generate override gossip config
python3 /usr/local/bin/generate_gossip_config.py

# Give visor an exec-able scratch area for hl-node
mkdir -p /dev/shm/hl && chmod 1777 /dev/shm/hl
export TMPDIR=/dev/shm/hl          # visor honours TMPDIR

# Run visor directly (running as root inside container is acceptable and avoids duplicate processes under Rosetta)
exec gosu hluser /home/hluser/hl-visor run-non-validator --replica-cmds-style recent-actions --serve-eth-rpc 