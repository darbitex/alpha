#[test_only]
module darbitex::tests {
    use std::vector;
    use std::string;
    use std::option;
    use std::bcs;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_framework::object::{Self, Object};
    use aptos_framework::fungible_asset::{Self, Metadata, MintRef};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin;

    use darbitex::pool;
    use darbitex::pool_factory;
    use darbitex::lp_coin;
    use darbitex::hook_wrapper;
    use darbitex::bridge;

    // ===== Test Constants =====
    const POOL_AMOUNT: u64 = 1_000_000_000_000; // 10,000 tokens (8 dec)

    // ===== MintRef Storage =====
    struct TestMints has key {
        mint_a: MintRef,
        mint_b: MintRef,
    }

    // ===== Helpers =====

    fun create_fa(creator: &signer, seed: vector<u8>, name: vector<u8>): (Object<Metadata>, MintRef) {
        let constructor_ref = object::create_named_object(creator, seed);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            &constructor_ref,
            option::none(),
            string::utf8(name),
            string::utf8(name),
            8,
            string::utf8(b""),
            string::utf8(b""),
        );
        let mint_ref = fungible_asset::generate_mint_ref(&constructor_ref);
        let metadata = object::object_from_constructor_ref<Metadata>(&constructor_ref);
        (metadata, mint_ref)
    }

    fun mint(ref: &MintRef, to: address, amount: u64) {
        let fa = fungible_asset::mint(ref, amount);
        primary_fungible_store::deposit(to, fa);
    }

    fun bal(addr: address, meta: Object<Metadata>): u64 {
        primary_fungible_store::balance(addr, meta)
    }

    /// Full protocol setup. Returns sorted (meta_a, meta_b).
    fun setup(framework: &signer, darbitex_signer: &signer): (Object<Metadata>, Object<Metadata>) {
        // Framework init
        timestamp::set_time_has_started_for_testing(framework);
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(framework);
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);

        // Account setup
        account::create_account_for_test(@darbitex);

        // Protocol init
        lp_coin::init(darbitex_signer);
        pool_factory::init_factory(darbitex_signer);
        let factory_addr = pool_factory::factory_address();
        pool::init_protocol(darbitex_signer, factory_addr);
        hook_wrapper::init(darbitex_signer);

        // Create test FA tokens (from a separate creator to avoid address conflicts)
        let (meta_x, mint_x) = create_fa(darbitex_signer, b"coin_x", b"CoinX");
        let (meta_y, mint_y) = create_fa(darbitex_signer, b"coin_y", b"CoinY");

        // Sort by BCS address order (factory requires sorted)
        let ax = bcs::to_bytes(&object::object_address(&meta_x));
        let ay = bcs::to_bytes(&object::object_address(&meta_y));
        let (meta_a, meta_b, mint_a, mint_b) = if (ax < ay) {
            (meta_x, meta_y, mint_x, mint_y)
        } else {
            (meta_y, meta_x, mint_y, mint_x)
        };

        // Mint plenty of tokens
        mint(&mint_a, @darbitex, POOL_AMOUNT * 10);
        mint(&mint_b, @darbitex, POOL_AMOUNT * 10);

        // Store MintRefs
        move_to(darbitex_signer, TestMints { mint_a, mint_b });

        (meta_a, meta_b)
    }

    /// Create a pool with equal amounts. Returns pool_addr.
    fun create_pool(
        darbitex_signer: &signer,
        meta_a: Object<Metadata>,
        meta_b: Object<Metadata>,
        amount: u64,
    ): address {
        pool_factory::create_canonical_pool(darbitex_signer, meta_a, meta_b, amount, amount);
        pool_factory::canonical_pool_address(meta_a, meta_b)
    }

    /// Mint test tokens to an address.
    fun give_tokens(to: address, amount: u64) acquires TestMints {
        let m = borrow_global<TestMints>(@darbitex);
        mint(&m.mint_a, to, amount);
        mint(&m.mint_b, to, amount);
    }

    // =========================================================
    //                       POOL TESTS
    // =========================================================

    #[test(darbitex = @darbitex, user = @0x100, framework = @0x1)]
    /// Basic swap: create pool, swap A→B, verify output and reserves.
    fun test_swap_basic(darbitex: &signer, user: &signer, framework: &signer) acquires TestMints {
        let (meta_a, meta_b) = setup(framework, darbitex);
        let pool_addr = create_pool(darbitex, meta_a, meta_b, POOL_AMOUNT);

        // Verify pool
        assert!(pool::pool_exists(pool_addr), 1);
        let (ra, rb) = pool::reserves(pool_addr);
        assert!(ra == POOL_AMOUNT && rb == POOL_AMOUNT, 2);

        // User swaps 1000 units of A → B
        account::create_account_for_test(@0x100);
        give_tokens(@0x100, 1_000_000);

        let before_b = bal(@0x100, meta_b);
        pool::swap_entry(user, pool_addr, meta_a, 1_000_000, 0);
        let after_b = bal(@0x100, meta_b);

        // User received some B
        assert!(after_b > before_b, 3);

        // Reserves updated correctly
        let (ra2, rb2) = pool::reserves(pool_addr);
        assert!(ra2 > ra, 4);  // A reserve increased
        assert!(rb2 < rb, 5);  // B reserve decreased
    }

    #[test(darbitex = @darbitex, user = @0x100, framework = @0x1)]
    /// Verify get_amount_out matches actual swap output.
    fun test_swap_quote_accuracy(darbitex: &signer, user: &signer, framework: &signer) acquires TestMints {
        let (meta_a, meta_b) = setup(framework, darbitex);
        let pool_addr = create_pool(darbitex, meta_a, meta_b, POOL_AMOUNT);

        // Quote
        let swap_in = 5_000_000; // 0.05 tokens
        let expected_out = pool::get_amount_out(pool_addr, swap_in, true);

        // Actual swap
        account::create_account_for_test(@0x100);
        give_tokens(@0x100, swap_in);
        let before_b = bal(@0x100, meta_b);
        pool::swap_entry(user, pool_addr, meta_a, swap_in, 0);
        let actual_out = bal(@0x100, meta_b) - before_b;

        // Quote should match actual
        assert!(expected_out == actual_out, 1);
    }

    #[test(darbitex = @darbitex, user = @0x100, framework = @0x1)]
    /// [CL-01] Min fee: small swaps still charge protocol fee.
    fun test_min_fee_on_small_swap(darbitex: &signer, user: &signer, framework: &signer) acquires TestMints {
        let (meta_a, meta_b) = setup(framework, darbitex);
        let pool_addr = create_pool(darbitex, meta_a, meta_b, POOL_AMOUNT);

        account::create_account_for_test(@0x100);
        give_tokens(@0x100, 100_000);

        // Swap 50,000 units (below EXTRA_FEE_DENOM=100,000)
        pool::swap_entry(user, pool_addr, meta_a, 50_000, 0);

        // Protocol fee should still be collected (min 1 unit)
        let (_, _, pa, _) = pool::pending_fees(pool_addr);
        assert!(pa >= 1, 1);
    }

    #[test(darbitex = @darbitex, user = @0x100, framework = @0x1)]
    #[expected_failure(abort_code = 3)] // E_SLIPPAGE
    /// Slippage protection: swap fails if output < min_out.
    fun test_swap_slippage_protection(darbitex: &signer, user: &signer, framework: &signer) acquires TestMints {
        let (meta_a, meta_b) = setup(framework, darbitex);
        let pool_addr = create_pool(darbitex, meta_a, meta_b, POOL_AMOUNT);

        account::create_account_for_test(@0x100);
        give_tokens(@0x100, 1_000_000);

        // Set min_out impossibly high → should fail
        pool::swap_entry(user, pool_addr, meta_a, 1_000_000, 999_999_999);
    }

    // =========================================================
    //                    LIQUIDITY TESTS
    // =========================================================

    #[test(darbitex = @darbitex, user = @0x100, framework = @0x1)]
    /// Add and remove liquidity: LP accounting is correct.
    fun test_add_remove_liquidity(darbitex: &signer, user: &signer, framework: &signer) acquires TestMints {
        let (meta_a, meta_b) = setup(framework, darbitex);
        let pool_addr = create_pool(darbitex, meta_a, meta_b, POOL_AMOUNT);

        account::create_account_for_test(@0x100);
        give_tokens(@0x100, POOL_AMOUNT);

        let before_a = bal(@0x100, meta_a);
        let before_b = bal(@0x100, meta_b);

        // Add liquidity (same ratio as pool)
        let add_amount = 100_000_000; // 1 token
        pool::add_liquidity(user, pool_addr, add_amount, add_amount);

        // User spent tokens
        let after_a = bal(@0x100, meta_a);
        assert!(after_a == before_a - add_amount, 1);

        // User has LP
        let lp_bal = lp_coin::balance(@darbitex, pool_addr, @0x100);
        assert!(lp_bal > 0, 2);

        // Remove all LP
        pool::remove_liquidity(user, pool_addr, lp_bal);

        // User got tokens back (approximately same, minus rounding)
        let final_a = bal(@0x100, meta_a);
        let final_b = bal(@0x100, meta_b);
        assert!(final_a >= before_a - 1, 3); // within 1 unit rounding
        assert!(final_b >= before_b - 1, 4);
    }

    // =========================================================
    //                     PAUSE TESTS
    // =========================================================

    #[test(darbitex = @darbitex, user = @0x100, framework = @0x1)]
    #[expected_failure(abort_code = 8)] // E_PAUSED
    /// Paused pool blocks swaps.
    fun test_pause_blocks_swap(darbitex: &signer, user: &signer, framework: &signer) acquires TestMints {
        let (meta_a, meta_b) = setup(framework, darbitex);
        let pool_addr = create_pool(darbitex, meta_a, meta_b, POOL_AMOUNT);

        // Pause
        pool::pause(darbitex, pool_addr);

        // Swap should fail
        account::create_account_for_test(@0x100);
        give_tokens(@0x100, 1_000_000);
        pool::swap_entry(user, pool_addr, meta_a, 1_000_000, 0);
    }

    #[test(darbitex = @darbitex, user = @0x100, framework = @0x1)]
    /// Paused pool still allows remove_liquidity (user exit path).
    fun test_pause_allows_withdrawal(darbitex: &signer, user: &signer, framework: &signer) acquires TestMints {
        let (meta_a, meta_b) = setup(framework, darbitex);
        let pool_addr = create_pool(darbitex, meta_a, meta_b, POOL_AMOUNT);

        // User adds liquidity
        account::create_account_for_test(@0x100);
        give_tokens(@0x100, POOL_AMOUNT);
        pool::add_liquidity(user, pool_addr, 100_000_000, 100_000_000);
        let lp = lp_coin::balance(@darbitex, pool_addr, @0x100);

        // Pause
        pool::pause(darbitex, pool_addr);

        // Remove should still work
        pool::remove_liquidity(user, pool_addr, lp);
        let lp_after = lp_coin::balance(@darbitex, pool_addr, @0x100);
        assert!(lp_after == 0, 1);
    }

    // =========================================================
    //                    FEE ACCOUNTING
    // =========================================================

    #[test(darbitex = @darbitex, user = @0x100, framework = @0x1)]
    /// Fee accounting: protocol fee accumulates and is withdrawable.
    fun test_protocol_fee_withdrawal(darbitex: &signer, user: &signer, framework: &signer) acquires TestMints {
        let (meta_a, meta_b) = setup(framework, darbitex);
        let pool_addr = create_pool(darbitex, meta_a, meta_b, POOL_AMOUNT);

        // Do a swap to generate fees
        account::create_account_for_test(@0x100);
        give_tokens(@0x100, 10_000_000_000); // 100 tokens
        pool::swap_entry(user, pool_addr, meta_a, 10_000_000_000, 0);

        // Check protocol fees accumulated
        let (_, _, pa, pb) = pool::pending_fees(pool_addr);
        assert!(pa > 0, 1); // fee on token A (input)

        // Admin withdraws
        let treasury_before = bal(@darbitex, meta_a);
        pool::withdraw_protocol_fee(darbitex, pool_addr);
        let treasury_after = bal(@darbitex, meta_a);
        assert!(treasury_after > treasury_before, 2);

        // Fees reset to 0
        let (_, _, pa2, _) = pool::pending_fees(pool_addr);
        assert!(pa2 == 0, 3);
    }

    // =========================================================
    //                  BRIDGE TESTS
    // =========================================================

    #[test(darbitex = @darbitex, framework = @0x1)]
    /// Bridge: creation works and does not abort.
    fun test_bridge_create(darbitex: &signer, framework: &signer) {
        let (meta_a, meta_b) = setup(framework, darbitex);
        bridge::create_bridge(darbitex, meta_a, meta_b, POOL_AMOUNT, POOL_AMOUNT);
        // If we reach here, bridge created successfully.
    }

    #[test(darbitex = @darbitex, framework = @0x1)]
    #[expected_failure(abort_code = 1)] // E_ZERO (lp_supply too small)
    /// [CL-04] Bridge requires minimum initial liquidity.
    fun test_bridge_min_initial_liquidity(darbitex: &signer, framework: &signer) {
        let (meta_a, meta_b) = setup(framework, darbitex);

        // Try to create bridge with tiny amounts (below MINIMUM_LIQUIDITY=1000)
        // lp_supply = 100 + 100 = 200 < 1000 → should fail
        bridge::create_bridge(darbitex, meta_a, meta_b, 100, 100);
    }

    // =========================================================
    //                BATCH QUOTE TESTS
    // =========================================================

    #[test(darbitex = @darbitex, framework = @0x1)]
    /// Multihop quote: single hop matches single quote.
    fun test_multihop_quote(darbitex: &signer, framework: &signer) {
        let (meta_a, meta_b) = setup(framework, darbitex);
        let pool_addr = create_pool(darbitex, meta_a, meta_b, POOL_AMOUNT);

        let single = pool::get_amount_out(pool_addr, 1_000_000, true);
        let multihop = pool::get_amount_out_multihop(
            vector[pool_addr], 1_000_000, vector[true],
        );
        assert!(multihop == single, 1);
    }

    // =========================================================
    //               ADMIN 2-STEP TRANSFER
    // =========================================================

    #[test(darbitex = @darbitex, new_admin = @0x200, framework = @0x1)]
    /// 2-step admin: propose → accept.
    fun test_admin_transfer(darbitex: &signer, new_admin: &signer, framework: &signer) {
        let (_, _) = setup(framework, darbitex);

        // Propose
        pool::propose_admin(darbitex, @0x200);

        // Accept
        account::create_account_for_test(@0x200);
        pool::accept_admin(new_admin);

        // Verify new admin
        let (admin, _, _) = pool::protocol_config();
        assert!(admin == @0x200, 1);
    }

    #[test(darbitex = @darbitex, fake = @0x999, framework = @0x1)]
    #[expected_failure(abort_code = 4)] // E_NOT_ADMIN
    /// 2-step admin: wrong address cannot accept.
    fun test_admin_transfer_wrong_accepter(darbitex: &signer, fake: &signer, framework: &signer) {
        let (_, _) = setup(framework, darbitex);

        pool::propose_admin(darbitex, @0x200);

        // Wrong signer tries to accept → should fail
        account::create_account_for_test(@0x999);
        pool::accept_admin(fake);
    }

    // =========================================================
    //              POOL VIEWS / REGISTRY
    // =========================================================

    #[test(darbitex = @darbitex, framework = @0x1)]
    /// Pool registry: get_all_pools returns created pools.
    fun test_pool_registry(darbitex: &signer, framework: &signer) {
        let (meta_a, meta_b) = setup(framework, darbitex);
        create_pool(darbitex, meta_a, meta_b, POOL_AMOUNT);

        let pools = pool_factory::get_all_pools();
        assert!(vector::length(&pools) == 1, 1);

        let count = pool_factory::pool_count();
        assert!(count == 1, 2);
    }
}
