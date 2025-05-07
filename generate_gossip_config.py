#!/usr/bin/env python3
"""
Generate ~/override_gossip_config.json for Hyperliquid automatically.

Priority order:
1. If the file specified by the env var VALIDATOR_IPS_FILE (default
   /run/secrets/validator_ips.txt) exists – use the IPs listed there.
2. Otherwise, parse the "Mainnet Non-Validator Seed Peers" section of
   README.md that is copied into the image at /app/README.md by the
   Dockerfile.  Every line in that fenced code-block is
   "operator,ip" CSV; we extract the IP addresses.

Outputs ~/override_gossip_config.json with the structure expected by
Hyperliquid.
"""
import json
import os
import pathlib
import re
import sys
from typing import List, Dict

# ---------- Config ---------- #
DEFAULT_IPS_FILE = os.getenv("VALIDATOR_IPS_FILE", "/run/secrets/validator_ips.txt")
README_PATH = os.getenv("README_PATH", "/app/README.md")
CHAIN = os.getenv("CHAIN", "Mainnet")
OUTPUT_PATH = pathlib.Path("/home/hluser/override_gossip_config.json")

_IP_REGEX = re.compile(r"^(?:\d{1,3}\.){3}\d{1,3}$")


def _is_valid_ip(ip: str) -> bool:
    """Basic IPv4 validation (0-255 not enforced – fine for this use-case)."""
    return bool(_IP_REGEX.match(ip))


def _load_ips_from_file(path: str) -> List[str]:
    """Return list of IP strings from a newline-separated file."""
    if not os.path.exists(path):
        return []
    ips: List[str] = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            ip = line.strip()
            if _is_valid_ip(ip):
                ips.append(ip)
    return ips


def _load_ips_from_readme(path: str) -> List[str]:
    if os.path.exists(path):
        content = pathlib.Path(path).read_text(encoding="utf-8")
    else:
        # Fallback: pull README from upstream repo
        remote_url = os.getenv("SEED_README_URL", "https://raw.githubusercontent.com/hyperliquid-dex/node/main/README.md")
        try:
            import urllib.request, ssl
            print(f"[INFO] Fetching seed peers from {remote_url}")
            context = ssl.create_default_context()
            with urllib.request.urlopen(remote_url, context=context, timeout=10) as resp:
                content = resp.read().decode()
        except Exception as e:
            print(f"[WARN] Failed to fetch remote README: {e}")
            return []

    # Find any fenced code block whose first line is operator_name,root_ips
    code_blocks = re.findall(r"```([\s\S]*?)```", content)
    block = None
    for cb in code_blocks:
        lines = [ln.strip() for ln in cb.splitlines() if ln.strip()]
        if lines and re.match(r"operator_name\s*,\s*root_ips", lines[0], re.I):
            block = "\n".join(lines[1:])  # skip header
            break
    if block is None:
        print("[WARN] Could not locate seed peer CSV block in README")
        return []

    ips: List[str] = []
    for line in block.splitlines():
        parts = [p.strip() for p in line.split(",") if p.strip()]
        if parts:
            candidate = parts[-1]
            if _is_valid_ip(candidate):
                ips.append(candidate)
    return ips


def main() -> None:
    ips: List[str] = []

    # 1. override file
    ips = _load_ips_from_file(DEFAULT_IPS_FILE)

    # 2. README fallback
    if not ips:
        ips = _load_ips_from_readme(README_PATH)

    # De-duplicate while preserving order
    seen = set()
    unique_ips = []
    for ip in ips:
        if ip not in seen:
            unique_ips.append(ip)
            seen.add(ip)

    cfg: Dict[str, object] = {
        "root_node_ips": [{"Ip": ip} for ip in unique_ips],
        "try_new_peers": True,
        "chain": CHAIN,
    }

    OUTPUT_PATH.write_text(json.dumps(cfg))
    print(f"[INFO] Wrote {OUTPUT_PATH} with {len(unique_ips)} root_node_ips")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"[ERROR] {e}")
        sys.exit(1) 