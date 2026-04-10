# Darbitex (alpha — DEPRECATED)

> ⚠️ **This repository is deprecated as of 2026-04-10.** Darbitex alpha is shutting down because its package upgrade authority is held by a single wallet, which would allow that key to override the 3-of-5 admin multisig via a malicious upgrade. Successor: **[darbitex/alpha-v1](https://github.com/darbitex/alpha-v1)** — same contracts, published from a multisig account so upgrades require the same threshold as admin actions. Full rationale in [DEPRECATED.md](./DEPRECATED.md).

Permissionless V4-style Hooks DEX on Aptos. Canonical pools, unowned, composable,
0.01% fee, decentralized frontend on Walrus.

**X / Twitter:** https://x.com/Darbitex

## Architecture

| Layer | Where |
|---|---|
| Smart contracts (Move) | `contracts/sources/` — 6 modules |
| Example hooks | `contracts/examples/` — 5 templates |
| Frontend (SPA) | `frontend/` — vanilla JS, no build step |
| Hosting | Walrus Sites (Sui), served via SuiNS `darbitex.sui` |
| Deployment records | `docs/DEPLOYMENT.md` |

## Contracts

Six Move modules deployed on Aptos mainnet as a single package:

- **`pool`** — Core AMM, constant-product swap, LP accounting, TWAP oracle, flash loans
- **`pool_factory`** — Canonical pool creation (1 per pair), hook auction, resale
- **`hook_wrapper`** — Mandatory aggregator gateway for hooked pools
- **`router`** — Multi-hop routing across plain and hooked pools
- **`bridge`** — Stableswap bridge for pegged assets
- **`lp_coin`** — Per-pool LP tracking (soulbound, friend-only mint/burn)

Key design choices:

- **Canonical pools** — exactly one pool per token pair, enforced by resource account
- **Permissionless hooks** — any Move module can become a pool hook via public auction
- **Internal reserve tracking** — reserves stored in struct, not derived from balance
- **Strict k-increase** on plain-pool swaps; flash loans only on hooked pools
- **Fixed 0.01% fee** — 90% LP, 5% hook, 5% protocol (on hooked pools)

Audited across 6 independent rounds — internal (x3), Gemini 2.5 Pro, DeepSeek R1,
Claude Opus, Grok 3, ChatGPT 4o, Mistral Large. 41 fixes applied.

## Example Hooks

`contracts/examples/` contains 5 single-file reference hooks:

| File | Purpose |
|---|---|
| `minimal_hook.move` | Bare pass-through scaffold — the pattern with no custom logic |
| `cooldown_hook.move` | Per-address cooldown between swaps (anti-sandwich) |
| `allowlist_hook.move` | Permissioned swap + LP access (KYC / institutional) |
| `twap_guard_hook.move` | Reject swaps when spot deviates >5% from TWAP |
| `volume_tracker_hook.move` | Records per-user volume, emits events (loyalty/airdrop) |

See `contracts/examples/README.md` for full developer guide including how to
publish a hook module and win an auction.

## Frontend

Single-page app in `frontend/`, no build step. Routes:

- `/` — Swap
- `/pools` — Pool list, add/remove liquidity, create pool, start hook auction
- `/portfolio` — LP positions viewer
- `/about` — Manifesto + audit table + architecture

**Wallet integration** follows AIP-62 Aptos Wallet Standard (Petra, Martian,
Nightly, Pontem via event-based discovery — no deprecated `window.petra` paths).
Google keyless login via `@aptos-labs/ts-sdk` (CDN, esm.sh).

**Hosting:** Walrus Sites with `ws-resources.json` SPA catchall route. Served
through SuiNS name `darbitex.sui` on `darbitex.wal.app`.

## Developing

### Contracts

```bash
cd contracts
aptos move compile --named-addresses darbitex=<YOUR_ADDR>
aptos move test --named-addresses darbitex=<YOUR_ADDR>
```

Publishing upgrade (compatible only — do not change public ABI):

```bash
aptos move publish --profile mainnet \
  --named-addresses darbitex=0x85d1e4047bde5c02b1915e5677b44ff5a6ba13452184d794da4658a4814efd30 \
  --included-artifacts none
```

### Frontend

No build step. Edit files in `frontend/`, open `frontend/index.html` locally
to test. For Walrus deployment:

```bash
site-builder --config ~/.config/walrus/sites-config.yaml update \
  --epochs 12 ./frontend <SITE_OBJECT_ID>
```

See `docs/DEPLOYMENT.md` for mainnet site object ID and SuiNS binding recipe.

## License

The Unlicense — public domain. Use it however you want.

## Links

- **Mainnet package:** `0x85d1e4047bde5c02b1915e5677b44ff5a6ba13452184d794da4658a4814efd30`
- **Explorer:** https://explorer.aptoslabs.com/account/0x85d1e4047bde5c02b1915e5677b44ff5a6ba13452184d794da4658a4814efd30/modules/code/pool_factory?network=mainnet
- **Site:** https://darbitex.wal.app
- **Twitter:** https://x.com/Darbitex
