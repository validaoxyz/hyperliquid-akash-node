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
import subprocess, shlex, shutil
from typing import List, Dict
from statistics import mean

# ---------- Config ---------- #
DEFAULT_IPS_FILE = os.getenv("VALIDATOR_IPS_FILE", "/run/secrets/validator_ips.txt")
README_PATH = os.getenv("README_PATH", "/app/README.md")
CHAIN = os.getenv("CHAIN", "Mainnet")
OUTPUT_PATH = pathlib.Path("/home/hluser/override_gossip_config.json")
PORT = int(os.getenv("GOSSIP_PORT", "4001"))
COUNT = int(os.getenv("PING_COUNT", "4"))
INTERVAL = float(os.getenv("PING_INTERVAL", "0.3"))  # seconds
ENABLE_RANK = os.getenv("RANK_GOSSIP", "1") == "1"

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

    def _extract(csv_text: str) -> List[str]:
        _ips: List[str] = []
        csv_line_re = re.compile(r"^[^,]+,\s*((?:\d{1,3}\.){3}\d{1,3})\s*$", re.M)
        for match in csv_line_re.finditer(csv_text):
            ip = match.group(1)
            if _is_valid_ip(ip):
                _ips.append(ip)
        return _ips

    ips = _extract(content)

    if not ips:
        # fallback remote even if local existed but had no peers
        remote_url = "https://raw.githubusercontent.com/hyperliquid-dex/node/main/README.md"
        try:
            import urllib.request, ssl
            print(f"[INFO] Local README had 0 peers, fetching {remote_url}")
            context = ssl.create_default_context()
            with urllib.request.urlopen(remote_url, context=context, timeout=10) as resp:
                remote_txt = resp.read().decode()
            ips = _extract(remote_txt)
        except Exception as e:
            print(f"[WARN] Remote fallback failed: {e}")

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

    # Optionally rank by latency using tcping
    if ENABLE_RANK and shutil.which("tcping"):
        ranked: List[str] = []
        for ip in unique_ips:
            try:
                cmd = ["tcping", "-c", str(COUNT), "-i", str(INTERVAL), ip, str(PORT)]
                res = subprocess.run(cmd, capture_output=True, text=True, timeout=PORT*COUNT)
                times = []
                for line in res.stdout.splitlines():
                    if "time=" in line:
                        # example "Reply from X time=123.456 ms"
                        try:
                            ms = float(line.split("time=")[1].split()[0])
                            times.append(ms)
                        except Exception:
                            pass
                avg = mean(times) if times else 9e9
            except Exception:
                avg = 9e9
            ranked.append((avg, ip))
        ranked.sort(key=lambda t: t[0])
        unique_ips = [ip for _, ip in ranked]
        print("[INFO] Latency ranking (ms, best 5):")
        for avg, ip in ranked[:5]:
            print(f"  {avg:.1f}\t{ip}")

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