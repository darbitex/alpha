/// Example #2 — Cooldown hook: per-address anti-sandwich guard.
///
/// Rejects any swap from an address that swapped within the last
/// COOLDOWN_SECS seconds on this pool. Breaks the simplest sandwich
/// pattern (attacker needs to open+close in the same block) while
/// letting normal retail traffic through unaffected.
///
/// This is NOT a full MEV shield — sophisticated bots rotate addresses
/// — but it's a one-line demonstration of how a V4 hook can enforce
/// per-user policy on top of an AMM with zero core changes.
///
/// Copy to your own package, edit `my_hook` address in Move.toml.
module my_hook::cooldown_hook {
    use std::signer;
    use aptos_std::table::{Self, Table};
    use aptos_framework::object::Object;
    use aptos_framework::fungible_asset::Metadata;
    use aptos_framework::primary_fungible_store;
    use aptos_framework::timestamp;

    use darbitex::pool::{Self, HookCap};

    // ===== Config =====
    const COOLDOWN_SECS: u64 = 2;

    // ===== Errors =====
    const E_NOT_DEPLOYER: u64 = 1;
    const E_ALREADY_INIT: u64 = 2;
    const E_NOT_INIT: u64 = 3;
    const E_COOLDOWN: u64 = 100;

    struct Witness has drop {}

    struct HookState has key {
        cap: HookCap,
        // per-address last swap timestamp (epoch seconds)
        last_swap: Table<address, u64>,
    }

    public entry fun init_hook(deployer: &signer, pool_addr: address) {
        assert!(signer::address_of(deployer) == @my_hook, E_NOT_DEPLOYER);
        assert!(!exists<HookState>(@my_hook), E_ALREADY_INIT);
        let cap = pool::claim_hook_cap<Witness>(pool_addr, Witness {});
        move_to(deployer, HookState { cap, last_swap: table::new() });
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
        let now = timestamp::now_seconds();

        // Check + update cooldown atomically.
        if (table::contains(&state.last_swap, swapper_addr)) {
            let last = *table::borrow(&state.last_swap, swapper_addr);
            assert!(now >= last + COOLDOWN_SECS, E_COOLDOWN);
            *table::borrow_mut(&mut state.last_swap, swapper_addr) = now;
        } else {
            table::add(&mut state.last_swap, swapper_addr, now);
        };

        let fa_in = primary_fungible_store::withdraw(swapper, metadata_in, amount_in);
        let fa_out = pool::swap_hooked(pool_addr, swapper_addr, fa_in, min_out, &state.cap);
        primary_fungible_store::deposit(swapper_addr, fa_out);
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
    public fun last_swap_of(swapper: address): u64 acquires HookState {
        let state = borrow_global<HookState>(@my_hook);
        if (table::contains(&state.last_swap, swapper)) {
            *table::borrow(&state.last_swap, swapper)
        } else { 0 }
    }
}
