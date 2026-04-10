# Darbitex alpha V0 is frozen

**Date:** 2026-04-10
**Final state:** every module in the Darbitex package at
`0x85d1e4047bde5c02b1915e5677b44ff5a6ba13452184d794da4658a4814efd30`
has been replaced with abort stubs, and the package's
`upgrade_policy` has been set to `immutable`. No call into the package
can succeed, and no future upgrade is possible — including from the
original publisher wallet. The package is permanently dead code on
Aptos mainnet.

**Successor:** [darbitex/alpha-v1](https://github.com/darbitex/alpha-v1),
published from a 3-of-5 multisig at
`0x810693eb5e17185ee7d80e548a48edcb60be4b1d56d33f8c1be716d9fb422d2e`.

## Why freeze a shut-down package

Darbitex alpha was already "retired" earlier on 2026-04-10 — the liquidity
was withdrawn from all six pools, the frontend at `darbitex.wal.app` was
replaced with a retired notice, and `DEPRECATED.md` was committed to this
repository explaining why a successor was needed. At that point the
package at `0x85d1e4…` was idle but still functional: its entry functions
were live and anyone with the original upgrade key could publish a new
version to it.

"Shut down" was not the same as "safe". Three risks remained:

1. **Upgrade key still hot.** The package `upgrade_policy` was `compatible`
   and the upgrade authority was a single wallet, not a multisig. A leak or
   theft of that wallet's private key would let an attacker push a
   malicious "compatible" upgrade that rewrites every function body. They
   could make `swap_entry` drain reserves to themselves, add a new
   `rug_all_pools` entry, or rewrite `assert_admin` to bypass the 3-of-5
   admin multisig. The admin-multisig protection was already
   theoretically-bypassable through this path — it was the reason we
   redeployed as V1 in the first place.

2. **Live callable surface for confused users.** The package still held
   `public entry fun create_canonical_pool`, `start_auction`, `swap_entry`,
   and friends. A third party could create a new pool on the deprecated
   package and attract users who did not know alpha was retired. Any
   aggregator or block explorer scraping the chain would still show the
   package as "live code, can be called". Nothing pointed them at V1 from
   inside the code itself.

3. **Reserve dust + hook auctions in an unguarded state.** The six alpha
   pools still held their minimum-liquidity locks (the 1000 LP that
   Uniswap-style AMMs keep permanently stuck to prevent first-depositor
   attacks), and three of them had open hook auctions with bid APT
   escrowed in the factory. None of those had a clean "sweep to attacker"
   path today, but they were still reachable surface on a package nobody
   intended to keep alive.

Freezing closes all three. Once every function aborts, there is nothing to
call that can produce an effect. Once `upgrade_policy` is `immutable`, no
key — compromised, lost, or not — can ever alter the bytecode again. The
package reduces to a few kilobytes of inert metadata sitting at a fixed
mainnet address forever.

## What was changed in this commit

1. Every `public entry fun`, `public fun`, `public(friend) fun`, and
   `#[view]` function in every Darbitex module had its body replaced with
   `abort E_FROZEN` (`E_FROZEN = 255`).
2. Every private `fun` body was replaced with the same abort, so the file
   is internally consistent and contains no dead code paths.
3. Every `struct` definition was preserved byte-for-byte — fields, order,
   abilities, phantom markers. Move's compatible-upgrade rules forbid
   struct layout changes, so this was required even for a one-way final
   publish.
4. Every function signature was preserved — visibility, type parameters,
   parameter names, parameter types, return types. `acquires` annotations
   were stripped because a body of `abort E_FROZEN` touches no storage, so
   the Move v2 compiler rejects the annotation as unnecessary. `acquires`
   is not part of the upgrade compatibility ABI.
5. `tests.move` was deleted. It was `#[test_only]` and therefore never
   compiled into the published bytecode anyway, but keeping it around
   would break local test runs now that every referenced function aborts.
6. `Move.toml`: `version = "4.0.0"`, `upgrade_policy = "immutable"`.

The package size on-chain shrank from about 39 KB to about 14 KB as a
result.

## Verification

| Item | Result |
|---|---|
| Publish TX | `0x51a0af78a2cf80a8628b8ae85fd27319343f7360b0d1be2d7fba285052300c54` |
| Version | 4833568353 |
| Gas | 1051 units |
| New `upgrade_policy` | `2` (immutable) |
| New `upgrade_number` | `3` |
| View call `pool::protocol_config` | `Move abort E_FROZEN(0xff)` |
| Entry call `pool::swap_entry` | `Move abort E_FROZEN(0xff)` |

Any call into any Darbitex module at the alpha address from now on will
abort with code 255. Any attempt to publish a new version — including
from the original publisher wallet — will fail at the `code` framework
with an "upgrade policy is immutable" error.

## What this does not touch

- The wallet `0x85d1e4047bde5c02b1915e5677b44ff5a6ba13452184d794da4658a4814efd30`
  itself is unchanged. Its APT balance, its role as owner of the V1
  multisig, and its separate `AptosArbBot` package (four unrelated modules
  at the same address) are all intact.
- The `0x1::code::PackageRegistry` entry for `AptosArbBot` is independent
  of Darbitex. Freezing one package does not freeze the others on the
  same account.
- The ANS name `darbitex.apt` was already re-targeted to the V1 publisher
  multisig earlier on 2026-04-10. It does not resolve to this frozen
  package.
- `darbitex.wal.app` and the SuiNS name `darbitex.sui` continue to serve
  the retired-notice page. They are unaffected by on-chain changes.

## Lesson

If a Move package ever holds user funds and you later decide to deprecate
it, "shutting it down" in the sense of draining liquidity and taking down
the frontend is not enough. The package remains a live target for its
upgrade key, and the upgrade key is god-mode under the `compatible`
policy. The final act of deprecation is either (a) a full freeze like
this, or (b) rotating the upgrade key to an air-gapped storage you trust
not to leak for the remaining lifetime of any asset that could ever
interact with the package. Freezing is easier.
