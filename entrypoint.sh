#!/usr/bin/env bash
set -euo pipefail

# If DEBUG_SHELL=1, skip visor startup and drop to a shell so the user
# can poke around inside the running Akash container.
if [[ "${DEBUG_SHELL:-0}" == "1" ]]; then
  echo "[INFO] DEBUG_SHELL requested – starting interactive bash instead of visor"
  exec bash
fi

# Start cron for pruning in background
cron

# Generate override gossip config
python3 /usr/local/bin/generate_gossip_config.py

# Work-around for providers that mount rootfs with `noexec` (Akash/CSI volumes).
# hl-visor respects TMPDIR for downloading hl-node, so point it at an exec-able tmpfs.
mkdir -p /dev/shm/hl && chmod 1777 /dev/shm/hl
export TMPDIR=/dev/shm/hl

# By default, keep the container running for debugging. Set START_VISOR=1
# to let the entrypoint launch hl-visor automatically.

if [[ "${START_VISOR:-0}" == "1" ]]; then
  echo "[INFO] START_VISOR=1 – launching hl-visor as root"
  exec /home/hluser/hl-visor run-non-validator \
       --replica-cmds-style recent-actions \
       --serve-eth-rpc
else
  echo "[INFO] Debug mode – container is idle, exec bash when ready"
  tail -f /dev/null
fi 