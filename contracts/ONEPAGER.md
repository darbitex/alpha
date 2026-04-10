# Darbitex

**Permissionless Hooks DEX on Aptos**

---

## What is Darbitex?

Darbitex is an automated market maker (AMM) built on Aptos that introduces **permissionless V4-style hooks** — allowing anyone to extend pool behavior without modifying the core protocol. Pools are canonical (one per pair), unowned, and composable by default.

---

## How It Works

```
                  ┌─────────────┐
  User / Agg. ──> │   Router    │ ──> Plain Pool (swap directly)
                  │  (multi-hop)│
                  └──────┬──────┘
                         │
                         └──────> Hook Wrapper ──> Hooked Pool
                                     │                  │
                                     │            ┌─────┴──────┐
                                     │            │  Hook Module│
                                     │            │  (your code)│
                                     │            └────────────┘
                                     └──> Flash Loan (repay + fee)
```

**Create a pool** — anyone deposits a token pair via the factory. One canonical pool per pair.

**Attach a hook** — win a public auction to attach your custom logic (MEV capture, dynamic fees, limit orders, TWAMM — anything). Hooks are tradeable assets.

**Swap** — users and aggregators call the same composable interface whether the pool is plain or hooked. No integration difference.

---

## Key Numbers

| Metric | Value |
|---|---|
| Swap fee | **0.01%** (1 basis point) |
| Fee split (hooked) | 90% LP, 5% hook, 5% protocol |
| Fee split (plain) | 90% LP, 10% protocol |
| Flash loan fee | Same as swap (0.01%) |
| Minimum liquidity | 1,000 units (locked forever) |
| Hook auction minimum | 0.1 APT |

---

## What Makes Darbitex Different

**Permissionless hooks** — No governance vote needed. Deploy your Move module, win the auction, attach it. Your hook runs on every swap through that pool.

**Hook marketplace** — Hooks are won via public auction and can be resold. This creates a market for pool-level innovation: MEV strategies, custom fee curves, oracle integrations.

**Aggregator-native** — Every pool exposes composable `swap()` returning FungibleAsset. Batch quoting (`get_amounts_out`), multi-hop simulation (`get_amount_out_multihop`), and pool discovery (`get_all_pools`) are built in. Integrating Darbitex is one function call.

**Ultra-low fees** — 0.01% total fee. Designed for high-frequency, high-volume trading where fee sensitivity matters.

**Unowned pools** — No admin key on pools. Liquidity cannot be rugged. Protocol admin can only pause (emergency) and collect protocol fees.

**FungibleAsset native** — Works with any Aptos FungibleAsset token. No Coin-type restrictions.

---

## Architecture

| Module | Role |
|---|---|
| **pool** | Core AMM. Swap, liquidity, flash loans, TWAP oracle, fee accounting. |
| **pool_factory** | Canonical pool creation, hook auctions, pool registry. |
| **hook_wrapper** | Aggregator gateway for hooked pools. Public swap, liquidity, flash loan. |
| **router** | Multi-hop entry points. Mixed routing (plain + hooked in one path). |
| **bridge** | Stableswap module with depeg protection for pegged asset pairs. |
| **lp_coin** | Per-pool LP token tracking. Soulbound (non-transferable). |

---

## Security

- Two full audit passes with **23+ findings fixed** across all severity levels
- 2-step admin transfer (propose/accept) prevents lockout
- Reentrancy guards on all state-changing operations
- Internal reserve tracking (not store balance) prevents donation attacks
- Flash loans restricted to hooked pools with same-token fee enforcement
- Strict k-invariant with 256-bit precision
- Admin force-remove for stuck hooks (unclaimed only)
- Overflow-safe TWAP accumulator
- Pools are Objects with transfer disabled — immovable and tamper-proof

---

## For Builders

**Hook developers**: Write a Move module that implements your logic. Claim the `HookCap` via witness pattern. Your module controls swap execution for that pool and earns 5% of fees.

**Aggregators**: Call `pool::get_all_pools()` to discover pools. Quote via `get_amounts_out()`. Route through `pool::swap()` (plain) or `hook_wrapper::swap()` (hooked). Both return `FungibleAsset` — fully composable.

**LP providers**: Deposit into any pool via factory or wrapper. Earn 90% of swap fees automatically. LP positions are per-pool and tracked on-chain.

---

## Links

- **Chain**: Aptos Mainnet
- **Package**: `darbitex` (v3.1.0)
- **License**: [TBD]

---

*Darbitex — Programmable liquidity, zero permission required.*
