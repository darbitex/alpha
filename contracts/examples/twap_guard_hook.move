/// Example #4 — TWAP guard hook: oracle-deviation circuit breaker.
///
/// Rejects swaps when the spot price has moved more than
/// MAX_DEVIATION_BPS from the pool's time-weighted average price over
/// the last TWAP_WINDOW seconds. Mitigates oracle-manipulation attacks
/// where a single-block pump pushes the pool off its equilibrium.
///
/// ### Caveat on precision
/// Darbitex's `pool::twap()` returns cumulative prices accumulated as
/// `reserve_b * elapsed / reserve_a` — naked integer division, no
/// fixed-point scaling. For pools where `reserve_b << reserve_a` the
/// cumulative effectively rounds to zero and the TWAP is unusable.
/// For the common case of balanced reserves and reasonable decimals
/// this works well enough. A production-grade guard should use UQ112
/// fixed-point inside a wrapper pool, or snapshot spot prices itself.
///
/// This example demonstrates the PATTERN (snapshot + deviation check),
/// not a bullet-proof TWAP implementation.
module my_hook::twap_guard_hook {
    use std::signer;
    use aptos_framework::object::Object;
    use aptos_framework::fungible_asset::Metadata;
    use aptos_framework::primary_fungible_store;
    use aptos_framework::timestamp;

    use darbitex::pool::{Self, HookCap};

    // ===== Config =====
    const MAX_DEVIATION_BPS: u128 = 500;     // 5% allowed drift
    const MIN_ELAPSED_SECS: u64 = 60;        // ignore if <60s since snapshot
    const SCALE: u128 = 1_000_000_000_000;   // 1e12 fixed point

    // ===== Errors =====
    const E_NOT_DEPLOYER: u64 = 1;
    const E_ALREADY_INIT: u64 = 2;
    const E_NOT_INIT: u64 = 3;
    const E_DEVIATION: u64 = 100;
    const E_EMPTY_RESERVES: u64 = 101;

    struct Witness has drop {}

    struct HookState has key {
        cap: HookCap,
        snapshot_cumul_a: u128,
        snapshot_cumul_b: u128,
        snapshot_ts: u64,
    }

    public entry fun init_hook(deployer: &signer, pool_addr: address) {
        assert!(signer::address_of(deployer) == @my_hook, E_NOT_DEPLOYER);
        assert!(!exists<HookState>(@my_hook), E_ALREADY_INIT);
        let cap = pool::claim_hook_cap<Witness>(pool_addr, Witness {});
        let (cumul_a, cumul_b, ts) = pool::twap(pool_addr);
        move_to(deployer, HookState {
            cap,
            snapshot_cumul_a: cumul_a,
            snapshot_cumul_b: cumul_b,
            snapshot_ts: ts,
        });
    }

    fun check_and_refresh(state: &mut HookState, pool_addr: address) {
        let now = timestamp::now_seconds();
        let elapsed = now - state.snapshot_ts;
        if (elapsed < MIN_ELAPSED_SECS) {
            // Not enough samples yet — skip check (first swaps after
            // init have no meaningful TWAP window).
            return
        };

        let (cumul_a_now, cumul_b_now, _) = pool::twap(pool_addr);
        let delta_a = cumul_a_now - state.snapshot_cumul_a;
        // twap price of a in b, scaled: (delta_a / elapsed) * SCALE
        let twap_scaled = delta_a * SCALE / (elapsed as u128);

        let (reserve_a, reserve_b) = pool::reserves(pool_addr);
        assert!(reserve_a > 0 && reserve_b > 0, E_EMPTY_RESERVES);
        let spot_scaled = (reserve_b as u128) * SCALE / (reserve_a as u128);

        // |spot - twap| / twap <= MAX_DEVIATION_BPS / 10000
        if (twap_scaled > 0) {
            let diff = if (spot_scaled > twap_scaled) {
                spot_scaled - twap_scaled
            } else {
                twap_scaled - spot_scaled
            };
            let bps = diff * 10_000 / twap_scaled;
            assert!(bps <= MAX_DEVIATION_BPS, E_DEVIATION);
        };

        // Roll snapshot forward so each swap guards against the last
        // MIN_ELAPSED_SECS window.
        state.snapshot_cumul_a = cumul_a_now;
        state.snapshot_cumul_b = cumul_b_now;
        state.snapshot_ts = now;
    }

    public entry fun swap_entry(
        swapper: &signer,
        pool_addr: address,
        metadata_in: Object<Metadata>,
        amount_in: u64,
        min_out: u64,
    ) acquires HookState {
        assert!(exists<HookState>(@my_hook), E_NOT_INIT);
        let state = borrow_global_mut<HookState>(@my_hook);
        check_and_refresh(state, pool_addr);

        let swapper_addr = signer::address_of(swapper);
        let fa_in = primary_fungible_store::withdraw(swapper, metadata_in, amount_in);
        let fa_out = pool::swap_hooked(pool_addr, swapper_addr, fa_in, min_out, &state.cap);
        primary_fungible_store::deposit(swapper_addr, fa_out);
    }

    // Liquidity is intentionally ungated: LPs should be able to exit
    // even during extreme deviation events, and adding liquidity
    // stabilizes the pool toward TWAP rather than away from it.
    public entry fun add_liquidity_entry(
        provider: &signer, pool_addr: address, amount_a: u64, amount_b: u64,
    ) acquires HookState {
        let state = borrow_global<HookState>(@my_hook);
        pool::add_liquidity_hooked(provider, pool_addr, amount_a, amount_b, &state.cap);
    }

    public entry fun remove_liquidity_entry(
        provider: &signer, pool_addr: address, lp_amount: u64,
    ) acquires HookState {
        let state = borrow_global<HookState>(@my_hook);
        pool::remove_liquidity_hooked(provider, pool_addr, lp_amount, &state.cap);
    }

    public entry fun claim_fees_entry(
        pool_addr: address, recipient: address,
    ) acquires HookState {
        let state = borrow_global<HookState>(@my_hook);
        pool::withdraw_hook_fee(pool_addr, recipient, &state.cap);
    }
}
