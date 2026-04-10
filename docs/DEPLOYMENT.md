# Darbitex Deployment Records

All mainnet addresses, site objects, and SuiNS bindings for the Darbitex v3.1
deployment on Aptos mainnet. Reference material for developers, auditors, and
future redeployments.

## Aptos Mainnet

### Package

- **Package ID:** `0x85d1e4047bde5c02b1915e5677b44ff5a6ba13452184d794da4658a4814efd30`
- **Deployer / Admin / Treasury:** `0x85d1e4047bde5c02b1915e5677b44ff5a6ba13452184d794da4658a4814efd30`
- **Version:** v3.1
- **Upgrade policy:** `compatible`
- **Initial deploy TX:** 2026-04-10

### Module addresses (all under the package)

- `0x85d1e40...efd30::pool`
- `0x85d1e40...efd30::pool_factory`
- `0x85d1e40...efd30::hook_wrapper`
- `0x85d1e40...efd30::router`
- `0x85d1e40...efd30::bridge`
- `0x85d1e40...efd30::lp_coin`

### Factory resource account

- **Factory shared resource:** `0x5ef0eebae87e7856c26a4ee2b98c36f80f721c9eb1100d7bcf8f9fc1e8a8bfe9`
- Derived via `account::create_resource_account(deployer, b"darbitex_factory")`

### Upgrade history

| # | Date | Change | TX | Gas |
|---|---|---|---|---|
| 1 | 2026-04-10 | `MIN_INITIAL_BID` 0.1 APT → 100 APT | `0x8f7d0ed212055f2f70cf166cbded9a343ed21fbe4a0472370f7a46a89f21d636` | 0.00121 APT |
| 2 | 2026-04-10 | Added `#[view]` to `lp_coin::balance` for RPC view endpoint | `0x854e7c5d0b13da769e568f177a89993310e0174419d37f1903886d3d4d91314d` | 0.00123 APT |

Both compatible upgrades — no ABI break.

## Mainnet Pools

### Native token pools (the active ones)

| Pool | Address | metadata_a | metadata_b | Seed |
|---|---|---|---|---|
| USDC/USDT native | `0xdb57c0bbbf8b637586d9abbbf045a12bfcd6f045aa10672cf6ebb24569f71616` | USDT (`0x357b0b74...`) | USDC (`0xbae20765...`) | 0.1 / 0.1 |
| APT/USDC native | `0xf7f7eb2850b6e6facddb204895c506f2880e173849eadd170f10b4bc8115e8b7` | APT (`0x0...0a`) | USDC | 0.1 / 0.1 |
| APT/USDT native | `0xe31eb9cf331081bb8b6043ce969f9fbf48d3a9a94fd5d3fd0772731396912c89` | APT | USDT | 0.1 / 0.1 |

Implicit initial price: 1 APT = 1 USD (symmetric seed, dev-only until reseeded
at market ratio ~$5/APT).

### Legacy non-native pools (created first, later abandoned)

Built with framework-owned deprecated USDC/USDT metadata (`owner == 0xa`, tiny
supply). Not referenced by the frontend TOKENS config. Each has a hook auction
running; after finalize they become hooked at `@darbitex`.

| Pool | Address | Note |
|---|---|---|
| APT/USDT-bridged | `0xdf52487516bd5f1cc7d54d64929a3abf3f5fc8e921661f1b97cdff850b469f14` | deprecated |
| APT/USDC-bridged | `0xa27c456a090f94f5ad1b7ae5d7b5789417ecabe2dcd342ea02c5707a02054de` | deprecated |
| USDC/USDT-bridged | `0x480ffc886e0aa7127259d612a683c4006200528fba3a270e2260f21fa5d80eb5` | deprecated |

## Token metadata (native, used by frontend)

| Symbol | Metadata address | Decimals | Issuer |
|---|---|---|---|
| APT | `0x000000000000000000000000000000000000000000000000000000000000000a` | 8 | Aptos framework |
| USDC | `0xbae207659db88bea0cbead6da0ed00aac12edcdda169e591cd41c94180b46f3b` | 6 | Circle native |
| USDT | `0x357b0b74bc833e95a115ad22604854d6b0fca151cecd94111770e5d6ffc9dc2b` | 6 | Tether native |

## Governance

Protocol admin and treasury are both multisig-controlled (moved from single
wallet on 2026-04-10).

| Role | Address | Threshold | Tool |
|---|---|---|---|
| Protocol admin | `0xf1b522effb90aef79395f97b9c39d6acbd8fdf84ec046361359a48de2e196566` | 3-of-5 | Petra Vault |
| Protocol treasury | `0xdbce89113a975826028236f910668c3ff99c8db8981be6a448caa2f8836f9576` | 2-of-3 | Petra Vault |

**What requires multisig approval:**
- `pool::propose_admin` (change admin) — admin 3-of-5
- `pool::set_treasury` — admin 3-of-5
- `pool::admin_force_remove_hook` — admin 3-of-5
- `pool::withdraw_protocol_fee` — admin 3-of-5 (routes to treasury multisig)
- Treasury fee sweep (any transfer from treasury multisig) — treasury 2-of-3

**What does NOT require multisig (permissionless):**
- Swaps, liquidity add/remove, flash loans, hook auctions — user signs their own TX

**What is still single-wallet (KNOWN RISK):**
- **Package upgrades** (`aptos move publish`) are still signed by the original
  deployer wallet `0x85d1e40...efd30`. This is an open single point of failure.
  Compatible upgrades allow rewriting function bodies, so an attacker with this
  key could drain pools via malicious upgrade. Two mitigation paths under
  consideration: (1) migrate package auth to resource account + SignerCap
  controlled by a multisig (one-way breaking change), or (2) freeze upgrades
  permanently via `code::freeze_code_object` (no future bug fixes possible).

## Protocol parameters

| Parameter | Value | Where |
|---|---|---|
| Swap fee total | 1 bps (0.01%) | `pool::FEE_BPS` |
| LP share | 90% of fee | `pool::LP_FEE_BPS` |
| Hook share | 5% | `pool::HOOK_FEE_BPS` |
| Protocol share | 5% | `pool::PROTOCOL_FEE_BPS` |
| Min initial auction bid | 100 APT | `pool_factory::MIN_INITIAL_BID` |
| Min bid increment | 10% | `pool_factory::MIN_BID_INCREMENT` |
| Min auction duration | 24 h | `pool_factory::MIN_AUCTION_DURATION` |
| Max auction duration | 30 days | `pool_factory::MAX_AUCTION_DURATION` |
| Anti-snipe window | 10 min | `pool_factory::ANTI_SNIPE_WINDOW` |
| Minimum liquidity | 1000 LP burned | `pool::MINIMUM_LIQUIDITY` |

## Frontend hosting (Walrus + Sui)

### Walrus site object

- **Site Object ID:** `0x050df98fbc08b6c4e5d8d41dc75835c2a2d491cc1c9687d8782a2b513a217718`
- **Storage:** 12 epochs (~6 months at 2 weeks/epoch on Walrus mainnet)
- **Base36 URL:** `https://4j9qcaz4iyt4l6khk3luiavmxh3kpm7dbnw2qf7oz8rpetfrs.wal.app`
- **Resources:** 11 files uploaded as Walrus quilts (`index.html`, `app.js`, `style.css`, `sw.js`, `manifest.json`, `favicon.svg`, `ws-resources.json`, plus `social/` assets)

Deploy / update with:

```bash
site-builder --config ~/.config/walrus/sites-config.yaml update \
  --epochs 12 ./frontend 0x050df98fbc08b6c4e5d8d41dc75835c2a2d491cc1c9687d8782a2b513a217718
```

### SuiNS bindings

#### `darbitex.sui` — primary

- **NFT object:** `0x1700cba4a0eb8b17f75bf4e446144417c273b122f15b04655611c0233591d719`
- **Owner:** `0x6915bc38bccd03a6295e9737143e4ef3318bcdc75be80a3114f317633bdd3304`
- **user_data:** `walrus_site_id` → site object above
- **target_address:** owner wallet
- **Live at:** https://darbitex.wal.app

#### Binding recipe (ControllerV2, working 2026-04-10)

The original SuiNS controller package `0xb7004c79...` fails with
`assert_app_is_authorized`. Use ControllerV2 instead:

- **Controller package:** `0x71af035413ed499710980ed8adb010bbf2cc5cacf4ab37c7710a4bb87eb58ba5`
- **SuiNS shared object:** `0x6e0ddefc0ad98889c04bab9639e512c21766c5e6366f89e696956d9be6952871`
- **Clock:** `0x6`

```bash
sui client call \
  --package 0x71af035413ed499710980ed8adb010bbf2cc5cacf4ab37c7710a4bb87eb58ba5 \
  --module controller \
  --function set_user_data \
  --args 0x6e0ddefc0ad98889c04bab9639e512c21766c5e6366f89e696956d9be6952871 \
         <YOUR_SUINS_NFT_ID> \
         "walrus_site_id" \
         "0x050df98fbc08b6c4e5d8d41dc75835c2a2d491cc1c9687d8782a2b513a217718" \
         0x6 \
  --gas-budget 50000000
```

To change value on an already-bound name, call `controller::unset_user_data` first.
To set target_address: `controller::set_target_address` with `[address]` option arg.

Cloudflare edge at `*.wal.app` caches 503 / old content for ~1h after binding
change. Use `?v=X` query param to bypass while waiting for CF revalidation.

## RPC

All state queryable via view functions:

- `pool_factory::get_all_pools(): vector<address>`
- `pool_factory::canonical_pool_address(meta_a, meta_b): address`
- `pool_factory::has_active_auction(meta_a, meta_b): bool`
- `pool::reserves(pool_addr): (u64, u64)`
- `pool::pool_info(pool_addr): (u64, u64, u64, bool)` — reserve_a, reserve_b, lp_supply, paused
- `pool::pool_tokens(pool_addr): (Object<Metadata>, Object<Metadata>)`
- `pool::pool_hook(pool_addr): (Option<address>, bool)`
- `pool::get_amount_out(pool_addr, amount_in, a_to_b): u64`
- `pool::twap(pool_addr): (u128, u128, u64)`
- `pool::pending_fees(pool_addr): (u64, u64, u64, u64)`
- `lp_coin::balance(registry_addr, pool_addr, owner): u64`
