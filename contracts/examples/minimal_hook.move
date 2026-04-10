/// Example #1 — Minimal pass-through hook for Darbitex V4 pools.
///
/// The "hello world" of Darbitex hooks. No custom logic: just wires
/// the witness -> HookCap -> wrapped entry points plumbing so a pool
/// whose `hook_addr == @my_hook` becomes usable.
///
/// To adapt: publish under your own address, win the hook auction for
/// a Darbitex pool with that address as `hook_addr`, call `init_hook`
/// once to claim the cap, then users route through the entries below.
///
/// Copy this file into your own Move package. Dependencies required in
/// Move.toml:
///   [dependencies.Darbitex]
///   local = "../darbit-dex"
///   [addresses]
///   my_hook = "<your address>"
module my_hook::minimal_hook {
    use std::signer;
    use aptos_framework::object::Object;
    use aptos_framework::fungible_asset::Metadata;
    use aptos_framework::primary_fungible_store;

    use darbitex::pool::{Self, HookCap};

    // ===== Errors =====
    const E_NOT_DEPLOYER: u64 = 1;
    const E_ALREADY_INIT: u64 = 2;
    const E_NOT_INIT: u64 = 3;

    // ===== Witness =====
    // The Darbitex factory calls `claim_hook_cap<Witness>(pool, Witness {})`.
    // type_info asserts that the witness module address == pool.hook_addr,
    // so ONLY this module can claim the cap after winning the auction.
    struct Witness has drop {}

    // ===== State =====
    // The cap lives inside the hook module, gated by `has key`. It never
    // leaves the module except by reference into pool:: calls.
    struct HookState has key {
        cap: HookCap,
    }

    // ===== Init =====
    /// Call ONCE after the pool factory sets hook_addr = @my_hook
    /// (i.e. after your auction is finalized). Idempotent-guarded.
    public entry fun init_hook(deployer: &signer, pool_addr: address) {
        assert!(signer::address_of(deployer) == @my_hook, E_NOT_DEPLOYER);
        assert!(!exists<HookState>(@my_hook), E_ALREADY_INIT);
        let cap = pool::claim_hook_cap<Witness>(pool_addr, Witness {});
        move_to(deployer, HookState { cap });
    }

    // ===== Swap =====
    public entry fun swap_entry(
        swapper: &signer,
        pool_addr: address,
        metadata_in: Object<Metadata>,
        amount_in: u64,
        min_out: u64,
    ) acquires HookState {
        assert!(exists<HookState>(@my_hook), E_NOT_INIT);
        let state = borrow_global<HookState>(@my_hook);
        let swapper_addr = signer::address_of(swapper);

        // Withdraw input, route through pool::swap_hooked, deposit output.
        let fa_in = primary_fungible_store::withdraw(swapper, metadata_in, amount_in);
        let fa_out = pool::swap_hooked(pool_addr, swapper_addr, fa_in, min_out, &state.cap);
        primary_fungible_store::deposit(swapper_addr, fa_out);
    }

    // ===== Liquidity (hooked pools block direct LP calls) =====
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

    // ===== Fee Collection =====
    /// The hook earns 0.0005% of swap volume (half of the 0.001% non-LP
    /// fee). Anyone can trigger the withdrawal — proceeds go to whatever
    /// `recipient` you set. Here we leave it as an open parameter; you
    /// could also hardcode it or gate by a signer check.
    public entry fun claim_fees_entry(
        pool_addr: address, recipient: address,
    ) acquires HookState {
        let state = borrow_global<HookState>(@my_hook);
        pool::withdraw_hook_fee(pool_addr, recipient, &state.cap);
    }
}
