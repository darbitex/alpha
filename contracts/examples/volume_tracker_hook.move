/// Example #5 — Volume tracker hook: pure analytics, zero gating.
///
/// Records cumulative per-address swap volume (denominated in token A
/// equivalent) and emits an event on every trade. No gates, no fees,
/// no admin. The ideal scaffold for loyalty programs, airdrop eligibility,
/// leaderboards, or on-chain trader reputation.
///
/// The hook still earns the protocol-allocated 0.0005% fee share — it
/// can be claimed by anyone and routed to a beneficiary of your choice
/// (e.g. a reward distributor contract).
module my_hook::volume_tracker_hook {
    use std::signer;
    use aptos_std::table::{Self, Table};
    use aptos_framework::event;
    use aptos_framework::object::{Self, Object};
    use aptos_framework::fungible_asset::Metadata;
    use aptos_framework::primary_fungible_store;

    use darbitex::pool::{Self, HookCap};

    // ===== Errors =====
    const E_NOT_DEPLOYER: u64 = 1;
    const E_ALREADY_INIT: u64 = 2;
    const E_NOT_INIT: u64 = 3;

    struct Witness has drop {}

    struct HookState has key {
        cap: HookCap,
        volume_of: Table<address, u128>,   // u128 to avoid overflow on busy pools
        total_volume: u128,
        metadata_a: address,
    }

    #[event]
    struct SwapRecorded has drop, store {
        swapper: address,
        volume_a_equiv: u128,
        new_user_total: u128,
        pool_total: u128,
    }

    public entry fun init_hook(deployer: &signer, pool_addr: address) {
        assert!(signer::address_of(deployer) == @my_hook, E_NOT_DEPLOYER);
        assert!(!exists<HookState>(@my_hook), E_ALREADY_INIT);
        let cap = pool::claim_hook_cap<Witness>(pool_addr, Witness {});
        let (meta_a, _) = pool::pool_tokens(pool_addr);
        move_to(deployer, HookState {
            cap,
            volume_of: table::new(),
            total_volume: 0,
            metadata_a: object::object_address(&meta_a),
        });
    }

    /// Converts any input amount into a token-A denominated volume.
    /// Uses current spot reserves for conversion — good enough for
    /// analytics but NOT for anything that needs manipulation-resistance.
    fun volume_in_a(
        state: &HookState,
        pool_addr: address,
        metadata_in: Object<Metadata>,
        amount_in: u64,
    ): u128 {
        let in_addr = object::object_address(&metadata_in);
        if (in_addr == state.metadata_a) {
            (amount_in as u128)
        } else {
            let (reserve_a, reserve_b) = pool::reserves(pool_addr);
            if (reserve_b == 0) { 0 } else {
                (amount_in as u128) * (reserve_a as u128) / (reserve_b as u128)
            }
        }
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
        let swapper_addr = signer::address_of(swapper);

        // Compute volume BEFORE the swap (reserves will shift afterward).
        let vol = volume_in_a(state, pool_addr, metadata_in, amount_in);

        let fa_in = primary_fungible_store::withdraw(swapper, metadata_in, amount_in);
        let fa_out = pool::swap_hooked(pool_addr, swapper_addr, fa_in, min_out, &state.cap);
        primary_fungible_store::deposit(swapper_addr, fa_out);

        // Record after a successful swap (if swap aborts, the whole
        // transaction reverts and nothing is recorded — desirable).
        let new_total = if (table::contains(&state.volume_of, swapper_addr)) {
            let slot = table::borrow_mut(&mut state.volume_of, swapper_addr);
            *slot = *slot + vol;
            *slot
        } else {
            table::add(&mut state.volume_of, swapper_addr, vol);
            vol
        };
        state.total_volume = state.total_volume + vol;

        event::emit(SwapRecorded {
            swapper: swapper_addr,
            volume_a_equiv: vol,
            new_user_total: new_total,
            pool_total: state.total_volume,
        });
    }

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

    #[view]
    public fun volume_of(user: address): u128 acquires HookState {
        let state = borrow_global<HookState>(@my_hook);
        if (table::contains(&state.volume_of, user)) {
            *table::borrow(&state.volume_of, user)
        } else { 0 }
    }

    #[view]
    public fun total_volume(): u128 acquires HookState {
        borrow_global<HookState>(@my_hook).total_volume
    }
}
