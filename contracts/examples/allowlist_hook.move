/// Example #3 — Allowlist hook: permissioned swap access.
///
/// Only addresses on the allowlist can swap. Liquidity is also gated
/// (an unpermissioned LP could otherwise launder swaps via zap-in).
/// Typical use-cases: KYC-compliant pools, institutional pools, pools
/// restricted to a tokenholder cohort.
///
/// NOTE: this example intentionally carries an `admin` field — gating
/// the allowlist against a signer is the core of the use-case. If you
/// want a trustless variant, replace the admin check with a proof of
/// NFT ownership, Merkle inclusion, or off-chain signature.
module my_hook::allowlist_hook {
    use std::signer;
    use aptos_std::table::{Self, Table};
    use aptos_framework::object::Object;
    use aptos_framework::fungible_asset::Metadata;
    use aptos_framework::primary_fungible_store;

    use darbitex::pool::{Self, HookCap};

    // ===== Errors =====
    const E_NOT_DEPLOYER: u64 = 1;
    const E_ALREADY_INIT: u64 = 2;
    const E_NOT_INIT: u64 = 3;
    const E_NOT_ADMIN: u64 = 4;
    const E_NOT_ALLOWED: u64 = 100;
    const E_ALREADY_ALLOWED: u64 = 101;
    const E_NOT_ON_LIST: u64 = 102;

    struct Witness has drop {}

    struct HookState has key {
        cap: HookCap,
        admin: address,
        allowed: Table<address, bool>,
    }

    public entry fun init_hook(deployer: &signer, pool_addr: address) {
        let addr = signer::address_of(deployer);
        assert!(addr == @my_hook, E_NOT_DEPLOYER);
        assert!(!exists<HookState>(@my_hook), E_ALREADY_INIT);
        let cap = pool::claim_hook_cap<Witness>(pool_addr, Witness {});
        move_to(deployer, HookState {
            cap,
            admin: addr,
            allowed: table::new(),
        });
    }

    // ===== Admin =====
    public entry fun add_allowed(admin: &signer, user: address) acquires HookState {
        let state = borrow_global_mut<HookState>(@my_hook);
        assert!(signer::address_of(admin) == state.admin, E_NOT_ADMIN);
        assert!(!table::contains(&state.allowed, user), E_ALREADY_ALLOWED);
        table::add(&mut state.allowed, user, true);
    }

    public entry fun remove_allowed(admin: &signer, user: address) acquires HookState {
        let state = borrow_global_mut<HookState>(@my_hook);
        assert!(signer::address_of(admin) == state.admin, E_NOT_ADMIN);
        assert!(table::contains(&state.allowed, user), E_NOT_ON_LIST);
        table::remove(&mut state.allowed, user);
    }

    /// 2-step admin transfer is left as an exercise. For an example
    /// we keep it single-step; read feedback_code_review before copying
    /// this into production.
    public entry fun transfer_admin(admin: &signer, new_admin: address) acquires HookState {
        let state = borrow_global_mut<HookState>(@my_hook);
        assert!(signer::address_of(admin) == state.admin, E_NOT_ADMIN);
        state.admin = new_admin;
    }

    // ===== Gated operations =====
    fun assert_allowed(state: &HookState, user: address) {
        assert!(
            table::contains(&state.allowed, user)
                && *table::borrow(&state.allowed, user),
            E_NOT_ALLOWED,
        );
    }

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
        assert_allowed(state, swapper_addr);

        let fa_in = primary_fungible_store::withdraw(swapper, metadata_in, amount_in);
        let fa_out = pool::swap_hooked(pool_addr, swapper_addr, fa_in, min_out, &state.cap);
        primary_fungible_store::deposit(swapper_addr, fa_out);
    }

    public entry fun add_liquidity_entry(
        provider: &signer, pool_addr: address, amount_a: u64, amount_b: u64,
    ) acquires HookState {
        let state = borrow_global<HookState>(@my_hook);
        assert_allowed(state, signer::address_of(provider));
        pool::add_liquidity_hooked(provider, pool_addr, amount_a, amount_b, &state.cap);
    }

    public entry fun remove_liquidity_entry(
        provider: &signer, pool_addr: address, lp_amount: u64,
    ) acquires HookState {
        let state = borrow_global<HookState>(@my_hook);
        // Removal is NOT gated — allowlist revocations must still let
        // LPs exit (otherwise funds can be trapped by policy changes).
        pool::remove_liquidity_hooked(provider, pool_addr, lp_amount, &state.cap);
    }

    public entry fun claim_fees_entry(
        pool_addr: address, recipient: address,
    ) acquires HookState {
        let state = borrow_global<HookState>(@my_hook);
        pool::withdraw_hook_fee(pool_addr, recipient, &state.cap);
    }

    #[view]
    public fun is_allowed(user: address): bool acquires HookState {
        let state = borrow_global<HookState>(@my_hook);
        table::contains(&state.allowed, user)
            && *table::borrow(&state.allowed, user)
    }
}
