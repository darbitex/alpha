# Darbitex alpha is deprecated

**Date:** 2026-04-10
**Status:** Shutting down. All liquidity being withdrawn. Frontend being replaced with a shutdown notice. Successor: **Darbitex alpha-v1** at https://github.com/darbitex/alpha-v1

## Why we are moving to alpha-v1

Darbitex alpha was deployed on Aptos mainnet on 2026-04-10 after two full audit rounds (23 + 10 findings, all fixed). Protocol admin and treasury were transferred to two separate multisigs (3-of-5 admin, 2-of-3 treasury) later the same day.

However, during post-deploy review, we identified that our multisig transfer only covered `pool::ProtocolConfig::admin` — it did **not** cover the package upgrade authority. On Aptos, package upgrade auth is tied to the account that originally called `aptos move publish`. For Darbitex alpha that is a single wallet (`0x85d1e4...efd30`), controlled by one private key on one machine.

### Why a single-wallet upgrade key is god mode

The Aptos `compatible` upgrade policy prevents removing public functions, changing signatures, or removing structs — but it does **not** prevent rewriting function bodies. An attacker holding our upgrade key could push a "compatible" upgrade that:

- Rewrites `pool::swap_internal` to drain reserves to an arbitrary address
- Rewrites `pool::withdraw_protocol_fee` to remove the admin check
- Rewrites `lp_coin::balance` to fake balances
- Rewrites `assert_admin` to always return true — **bypassing the 3-of-5 admin multisig entirely**
- Adds a new entry function like `rug_all_pools(attacker: &signer)` that drains everything

The 3-of-5 admin multisig we set up is only as strong as the weakest link, and the weakest link was the single-sig upgrade wallet. Our LP positions, pool reserves, and accumulated protocol fees were all exposed to a single key compromise. This is unacceptable for a protocol that invites others to deposit.

### Why we cannot fix it in place

Aptos package upgrade authority is bound to the publisher account at publish time. There is no `transfer_upgrade_authority` function. The only ways to change it are:

1. **Freeze the package permanently** (`code::freeze_code_object`) — irreversible, no future bug fixes
2. **Migrate to a resource account + SignerCap pattern** — requires redeploy to a new address
3. **Redeploy from a multisig publisher account** — requires redeploy to a new address

Options 2 and 3 both mean a fresh deployment at a fresh address. Rather than patch alpha and live with migration complexity on a barely-used deployment, we are doing a clean restart.

## What alpha-v1 changes

**The contracts themselves are essentially unchanged.** The audited code (v3.1) is solid. What changes is **who holds the upgrade key**:

- **Publisher = Aptos multisig account** (`0x1::multisig_account`), not a single wallet
- Bootstrap as **1-of-1 multisig** for deployment ergonomics (single owner can propose+execute back-to-back)
- After smoke testing, **add owners and raise threshold to 3-of-5** — the multisig address is stable under owner/threshold changes, so the package upgrade auth seamlessly becomes 3-of-5 without any on-chain migration
- Net result: from day one, upgrading the Darbitex package requires the same 3-of-5 threshold as changing the protocol admin. No single key can drain the protocol.

Secondary changes in alpha-v1:

- Fresh publisher wallet (the alpha upgrade wallet is considered reputationally burned — never touch production again)
- Repo reset at https://github.com/darbitex/alpha-v1 (this repo tagged `v0-alpha-final` and archived)
- Walrus frontend redeployed to a new site object; `darbitex.wal.app` re-bound after V1 is stable

## Alpha on-chain artifacts (for historical reference)

- Package: `0x85d1e4047bde5c02b1915e5677b44ff5a6ba13452184d794da4658a4814efd30`
- Factory: `0x5ef0eebae87e7856c26a4ee2b98c36f80f721c9eb1100d7bcf8f9fc1e8a8bfe9`
- Admin multisig (now orphaned): `0xf1b522effb90aef79395f97b9c39d6acbd8fdf84ec046361359a48de2e196566`
- Treasury multisig (now orphaned): `0xdbce89113a975826028236f910668c3ff99c8db8981be6a448caa2f8836f9576`
- See `docs/DEPLOYMENT.md` for pool addresses and TX history.

The alpha package cannot be deleted from Aptos — it will exist at its address forever. After LP withdrawal it will simply hold empty pools. Do not interact with it.

## Lesson for others

If you are deploying a Move package on Aptos and plan to hold user funds: **the account that publishes is the account that can upgrade — and upgrade means god mode.** Plan your publisher as carefully as you plan your admin. Multisig admin without multisig publisher is security theater.
