# Darbitex Hook Examples

Single-file reference implementations of permissionless V4 hooks on
Darbitex (Aptos mainnet). Each file is standalone — copy into your own
Move package, edit the `my_hook` address in `Move.toml`, and publish.

| File | Purpose | State | Admin |
|---|---|---|---|
| `minimal_hook.move` | Bare pass-through scaffold — the pattern with no custom logic | none | no |
| `cooldown_hook.move` | Per-address cooldown between swaps (anti-sandwich) | `Table<address,u64>` | no |
| `allowlist_hook.move` | Permissioned swap + LP access (KYC / institutional) | allowlist table | yes |
| `twap_guard_hook.move` | Reject swaps when spot deviates >5% from TWAP | cumulative snapshot | no |
| `volume_tracker_hook.move` | Records per-user volume, emits events (loyalty/airdrop scaffold) | volume table | no |

All five expose the same four entries so LPs and swappers can interact
with a hooked pool:
- `init_hook(deployer, pool_addr)` — call once after winning the auction
- `swap_entry(swapper, pool_addr, metadata_in, amount_in, min_out)`
- `add_liquidity_entry(provider, pool_addr, amount_a, amount_b)`
- `remove_liquidity_entry(provider, pool_addr, lp_amount)`
- `claim_fees_entry(pool_addr, recipient)` — withdraw the hook's share
  of the 0.001% non-LP fee (hook gets half, protocol gets half).

## Hook lifecycle on Darbitex

```
  deploy hook module  →  start_auction  →  win  →  finalize  →  init_hook  →  live
       (you)              (≥100 APT)       (24h)    (anyone)     (you)
```

### 1. Deploy your hook package

```bash
aptos move publish \
  --profile mainnet \
  --named-addresses my_hook=<YOUR_ADDR> \
  --included-artifacts none
```

Use the same `<YOUR_ADDR>` as the auction bidder — Darbitex gates the
HookCap claim on the witness type's module address, so the two must
match.

### 2. Bid in the auction

Minimum initial bid is **100 APT** (constant in `pool_factory`). The
bid is escrowed by the factory; on finalize it is forwarded to the
protocol treasury (or to the prior hook owner for resales).

```bash
aptos move run \
  --profile mainnet \
  --function-id 0x85d1e4047bde5c02b1915e5677b44ff5a6ba13452184d794da4658a4814efd30::pool_factory::start_auction \
  --args \
    object:<METADATA_A> \
    object:<METADATA_B> \
    address:<YOUR_ADDR> \
    u64:10000000000 \
    u64:86400
```

- `u64:10000000000` = 100 APT (100 × 10⁸ octas)
- `u64:86400` = 24h duration (min). Max 30 days.
- Pair ordering: `metadata_a < metadata_b` by bytes. Use
  `pool_factory::canonical_pool_address` as a view to verify.

Anti-snipe: any bid within the last 10 minutes extends the auction
end by 10 min. Bid increment is +10%.

### 3. After the deadline — finalize

Anyone can finalize once `now >= end_time`. It sets `pool.hook_addr`
to your address and transfers the winning bid to the treasury.

```bash
aptos move run \
  --profile mainnet \
  --function-id 0x85d1e4047bde5c02b1915e5677b44ff5a6ba13452184d794da4658a4814efd30::pool_factory::finalize_auction \
  --args \
    object:<METADATA_A> \
    object:<METADATA_B>
```

### 4. Claim your HookCap

```bash
aptos move run \
  --profile mainnet \
  --function-id <YOUR_ADDR>::minimal_hook::init_hook \
  --args address:<POOL_ADDR>
```

From this point the pool routes through **your** module. All plain
`pool::swap`, `pool::add_liquidity`, `pool::remove_liquidity` calls
will abort with `E_HOOK_REQUIRED` — users must call
`<YOUR_ADDR>::<module>::swap_entry` etc instead.

## Gotchas

- **Do not block liquidity removal.** If your hook gates LP operations,
  always leave `remove_liquidity_entry` open (see `allowlist_hook`).
  Otherwise a policy change can trap LP funds.
- **Flash loans require HookCap.** Not shown in examples, but
  `pool::flash_borrow_hooked` / `repay` accept the cap too. Expose an
  entry if you want flash loans enabled on your pool.
- **Hook gets paid via `withdraw_hook_fee`.** Fees accrue per-swap in
  `pool.hook_fee_a` / `hook_fee_b` and are withdrawable to any address
  the hook designates. The example exposes this as a public entry with
  an arbitrary `recipient` parameter — gate this however fits your
  model (signer check, hardcoded beneficiary, DAO vote, etc.).
- **`claim_hook_cap` is one-shot.** If your `HookState` ever gets
  destroyed, you need an `admin_force_remove_hook` call from the
  protocol admin to reset the pool before re-claiming. Design your
  resources so they can't be accidentally destroyed.
- **Witness module address is load-bearing.** Renaming the module or
  changing the published address after winning an auction invalidates
  your ability to claim the cap.

## Mainnet references

- Darbitex package: `0x85d1e4047bde5c02b1915e5677b44ff5a6ba13452184d794da4658a4814efd30`
- Factory resource account: `0x5ef0eebae87e7856c26a4ee2b98c36f80f721c9eb1100d7bcf8f9fc1e8a8bfe9`
- Existing pools: see `pool_factory::all_pool_addresses` view
