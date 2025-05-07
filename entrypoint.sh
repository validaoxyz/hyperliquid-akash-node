#!/usr/bin/env bash
set -euo pipefail

# Start cron for pruning in background
cron

# Generate override gossip config
python3 /usr/local/bin/generate_gossip_config.py

# Work-around for providers that mount rootfs with `noexec` (Akash/CSI volumes).
# hl-visor respects TMPDIR for downloading hl-node, so point it at an exec-able tmpfs.
mkdir -p /dev/shm/hl && chmod 1777 /dev/shm/hl
export TMPDIR=/dev/shm/hl

# Run visor directly (running as root inside container is acceptable and avoids duplicate processes under Rosetta)
exec gosu hluser /home/hluser/hl-visor run-non-validator --replica-cmds-style recent-actions --serve-evm-rpc 