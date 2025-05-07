#!/usr/bin/env bash
# ping_gossip.sh — quick RTT checker for Hyperliquid root_node_ips
#
# Usage:
#   ./ping_gossip.sh [override_gossip_config.json]
#
# Optional env vars (defaults shown):
#   PORT=4001           # TCP port to probe
#   COUNT=4             # Probes per IP
#   INTERVAL=300ms      # Delay between probes: "300ms", "0.3", "1" …

set -u                              # abort on undefined vars

# ───────────────────────── config ─────────────────────────
FILE=${1:-override_gossip_config.json}
PORT=${PORT:-4001}
COUNT=${COUNT:-4}
INTERVAL=${INTERVAL:-300ms}

# ──────────────────────── checks ─────────────────────────
command -v tcping >/dev/null 2>&1 || { echo '[ERROR] tcping not found' >&2; exit 1; }
[[ -r $FILE ]] || { printf '[ERROR] Cannot read “%s”\n' "$FILE" >&2; exit 1; }

# turn “123ms” into seconds for tcping builds that want seconds
if [[ $INTERVAL =~ ^([0-9]+)ms$ ]]; then
  INTERVAL=$(awk "BEGIN{printf \"%.3f\", ${BASH_REMATCH[1]}/1000}")
fi

# ─────────────────── helpers ──────────────────────────────
get_ips() {
  if command -v jq >/dev/null 2>&1; then
    jq -r '.root_node_ips[].Ip' "$FILE"
  else
    grep -oE '"Ip"[[:space:]]*:[[:space:]]*"[^"]+"' "$FILE" | awk -F'"' '{print $4}'
  fi
}

ping_ip() {
  local ip=$1 out avg
  # redirect stdin from /dev/null so tcping doesn’t swallow the while-loop’s input
  out=$(tcping -c "$COUNT" -i "$INTERVAL" "$ip" "$PORT" < /dev/null 2>/dev/null || true)

  avg=$(awk -F'time=' '/time=/{gsub(/ ms/,"",$2); s+=$2; n++}
                      END{if(n) printf "%.3f", s/n}' <<<"$out")
  [[ -z $avg ]] && avg=999999
  printf "%8.3f %s\n" "$avg" "$ip"
}

# ──────────────────── main ───────────────────────────────
total=$(get_ips | wc -l)
printf 'Probing %d IPs on port %d (%d× each, %s interval)…\n' \
       "$total" "$PORT" "$COUNT" "$INTERVAL"

( while read -r ip; do
    ping_ip "$ip"
  done < <(get_ips)
) | sort -n | awk '{printf "%-16s %s ms\n", $2, $1}'
