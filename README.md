# Hyperliquid Akash Node

A self-contained **Docker image** and deployment recipe for running a
Hyperliquid non-validator node on the
[Akash](https://akash.network) decentralized compute marketplace.

> **Highlights**
>
> • Builds for `linux/amd64` and is automatically published to GitHub
>   Container Registry at
>   `ghcr.io/validaoxyz/hyperliquid-akash-node:latest` every push to
>   `main`.<br/>
> • Generates `override_gossip_config.json` at container start-up by
>   parsing the upstream seed-peer list (or using a secret file you
>   provide).<br/>
> • Exposes **gossip ports 4000-4010** and **EVM RPC on 3001** by default
>   (`--serve-eth-rpc`).<br/>
> • Includes an internal cron job that prunes data older than **60 min**
>   every **5 min** so the node never fills the disk.

---

## Quick start (Docker)

```bash
# Pull the latest published image
docker pull ghcr.io/validaoxyz/hyperliquid-akash-node:latest

# Run locally (Mainnet)
# ──────────────────────
#   - Exposes gossip + EVM RPC ports
#   - Stores chain data in ./data on the host machine
#
mkdir -p ./data

docker run -it --rm \
  -e CHAIN=Mainnet \
  -p 4001:4001 -p 4002:4002 -p 3001:3001 \
  -v $(pwd)/data:/home/hluser/hl/data \
  ghcr.io/validaoxyz/hyperliquid-akash-node:latest
```

Once logs show the visor is running you can call the EVM RPC e.g.

```bash
curl -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  http://localhost:3001/evm
```

---

## Deploy to Akash

Create `deploy.yaml` (SDL v2) and upload through the usual bidding flow.
Only the important bits are shown—adjust CPU/RAM/pricing to taste.

```yaml
---
version: "2.0"

services:
  hl-node:
    image: ghcr.io/validaoxyz/hyperliquid-akash-node:latest
    env:
      - CHAIN=Mainnet                # or Testnet
    expose:
      # EVM RPC
      - port: 3001
        as: 3001
        to:
          - global: true

      # Gossip ports 4000-4010
      - port: 4000
        as: 4000
        to: [{ global: true }]
      - port: 4001
        as: 4001
        to: [{ global: true }]
      - port: 4002
        as: 4002
        to: [{ global: true }]
      - port: 4003
        as: 4003
        to: [{ global: true }]
      - port: 4004
        as: 4004
        to: [{ global: true }]
      - port: 4005
        as: 4005
        to: [{ global: true }]
      - port: 4006
        as: 4006
        to: [{ global: true }]
      - port: 4007
        as: 4007
        to: [{ global: true }]
      - port: 4008
        as: 4008
        to: [{ global: true }]
      - port: 4009
        as: 4009
        to: [{ global: true }]
      - port: 4010
        as: 4010
        to: [{ global: true }]

    params:
      storage:
        data:
          mount: /home/hluser/hl/data   # persistent chain data

profiles:
  compute:
    hl-node:
      resources:
        cpu:
          units: 4
        memory:
          size: 32Gi
        storage:
          - size: 10Gi                # root filesystem
          - name: data
            size: 400Gi
            attributes:
              persistent: true
              class: beta3
  placement:
    dcloud:
      pricing:
        hl-node:
          denom: uakt
          amount: 1000

deployment:
  hl-node:
    dcloud:
      profile: hl-node
      count: 1