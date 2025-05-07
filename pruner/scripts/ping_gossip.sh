#!/usr/bin/env bash
# ping_gossip.sh – quick RTT checker for Hyperliquid root_node_ips
# Usage: ./ping_gossip.sh [override_gossip_config.json]
# Requires: tcping (apt package) and optionally jq.
set -euo pipefail

if ! command -v tcping >/dev/null 2>&1; then
  echo "[ERROR] tcping not found in PATH" >&2
  exit 1
fi

FILE="${1:-$HOME/override_gossip_config.json}"
PORT=${PORT:-4001}
COUNT=${COUNT:-4}
INTERVAL=${INTERVAL:-300ms}

get_ips() {
  if command -v jq >/dev/null 2>&1; then
      jq -r '.root_node_ips[].Ip' "$FILE"
  else
      grep -oE '"Ip"[[:space:]]*:[[:space:]]*"[^"]+"' "$FILE" | awk -F'"' '{print $4}'
  fi
}

ping_ip() {
  local ip="$1"
  local avg
  avg=$(tcping -c "$COUNT" -i "$INTERVAL" -q "$ip" "$PORT" 2>/dev/null | \
        awk -F'[/ ]' '/rtt/ {print $(NF-1)}')
  [[ -z "$avg" ]] && avg=999999
  printf "%8.3f %s\n" "$avg" "$ip"
}

N=$(get_ips | wc -l || true)
if [[ "$N" == "0" ]]; then
  echo "[ERROR] No IPs found in $FILE" >&2; exit 1; fi
echo "Probing $N IPs on port $PORT ($COUNT× each)…"
while read -r ip; do
    ping_ip "$ip"
done < <(get_ips) | sort -n | awk '{printf "%-16s %s ms\n", $2, $1}' 