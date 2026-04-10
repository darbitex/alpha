/// Frozen. This module is deprecated and every callable function aborts.

module darbitex::pool {
    use std::vector;
    use std::option::{Option};
    use aptos_framework::object::{Self, Object, ExtendRef};
    use aptos_framework::fungible_asset::{FungibleAsset, Metadata};

    const E_FROZEN: u64 = 255;

    struct ProtocolConfig has key {
        admin: address,
        pending_admin: Option<address>,
        treasury: address,
        factory_addr: address,
    }

    struct HookCap has store {
        pool_addr: address,
        hook_addr: address,
    }

    struct Pool has key {
        metadata_a: Object<Metadata>,
        metadata_b: Object<Metadata>,
        extend_ref: ExtendRef,
        reserve_a: u64,
        reserve_b: u64,
        locked: bool,
        paused: bool,
        lp_supply: u64,
        total_swaps: u64,
        total_volume_a: u128,
        total_volume_b: u128,
        last_price_a_cumulative: u128,
        last_price_b_cumulative: u128,
        last_block_timestamp: u64,
        hook_addr: Option<address>,
        hook_claimed: bool,
        hook_fee_a: u64,
        hook_fee_b: u64,
        protocol_fee_a: u64,
        protocol_fee_b: u64,
    }

    struct FlashReceipt {
        pool_addr: address,
        k_before_hi: u128,
        k_before_lo: u128,
        borrowed_a: bool,
        borrow_amount: u64,
        store_before: u64,
    }

    #[event]
    struct ProtocolConfigUpdated has drop, store {
        admin: address, treasury: address, factory_addr: address,
    }

    #[event]
    struct PoolCreated has drop, store {
        pool_addr: address, metadata_a: address, metadata_b: address,
    }

    #[event]
    struct HookSet has drop, store { pool_addr: address, hook_addr: address }

    #[event]
    struct HookClaimed has drop, store { pool_addr: address, hook_addr: address }

    #[event]
    struct HookRemoved has drop, store { pool_addr: address, old_hook: address }

    #[event]
    struct Swapped has drop, store {
        swapper: address, pool_addr: address,
        amount_in: u64, amount_out: u64, a_to_b: bool,
        lp_fee: u64, hook_fee: u64, protocol_fee: u64,
        timestamp: u64,
    }

    #[event]
    struct LiquidityAdded has drop, store {
        provider: address, pool_addr: address,
        amount_a: u64, amount_b: u64, lp_minted: u64,
    }

    #[event]
    struct LiquidityRemoved has drop, store {
        provider: address, pool_addr: address,
        amount_a: u64, amount_b: u64, lp_burned: u64,
    }

    #[event]
    struct FlashBorrowed has drop, store {
        borrower: address, pool_addr: address, amount: u64,
    }

    #[event]
    struct FeeWithdrawn has drop, store {
        pool_addr: address, recipient: address,
        amount_a: u64, amount_b: u64, fee_type: u8,
    }

    #[event]
    struct PoolPaused has drop, store { pool_addr: address, paused: bool }

    fun mul_u128(a: u128, b: u128): (u128, u128) {
        abort E_FROZEN
    }

    fun gt_u256(a_hi: u128, a_lo: u128, b_hi: u128, b_lo: u128): bool {
        abort E_FROZEN
    }

    fun sqrt(x: u128): u64 {
        abort E_FROZEN
    }

    fun assert_admin(account: &signer) {
        abort E_FROZEN
    }

    fun assert_factory(account: &signer) {
        abort E_FROZEN
    }

    fun assert_valid_cap(pool: &Pool, cap: &HookCap) {
        abort E_FROZEN
    }

    public entry fun init_protocol(deployer: &signer, factory_addr: address) {
        abort E_FROZEN
    }

    public entry fun propose_admin(admin: &signer, new_admin: address) {
        abort E_FROZEN
    }

    public entry fun accept_admin(new_admin: &signer) {
        abort E_FROZEN
    }

    public entry fun set_treasury(admin: &signer, new_treasury: address) {
        abort E_FROZEN
    }

    public fun create_pool(
        factory_signer: &signer,
        constructor_ref: &object::ConstructorRef,
        metadata_a: Object<Metadata>,
        metadata_b: Object<Metadata>,
        amount_a: u64,
        amount_b: u64,
    ) {
        abort E_FROZEN
    }

    public fun set_hook(
        factory_signer: &signer, pool_addr: address, hook_addr: address,
    ) {
        abort E_FROZEN
    }

    public fun remove_hook(
        factory_signer: &signer, pool_addr: address,
    ) {
        abort E_FROZEN
    }

    public fun claim_hook_cap<W: drop>(pool_addr: address, _witness: W): HookCap {
        abort E_FROZEN
    }

    public fun hook_cap_pool(cap: &HookCap): address {
        abort E_FROZEN
    }

    public fun hook_cap_addr(cap: &HookCap): address {
        abort E_FROZEN
    }

    public fun destroy_hook_cap(cap: HookCap) {
        abort E_FROZEN
    }

    public fun withdraw_hook_fee(
        pool_addr: address, recipient: address, cap: &HookCap,
    ) {
        abort E_FROZEN
    }

    public entry fun withdraw_protocol_fee(
        admin: &signer, pool_addr: address,
    ) {
        abort E_FROZEN
    }

    fun update_twap(pool: &mut Pool) {
        abort E_FROZEN
    }

    fun swap_internal(
        pool: &mut Pool,
        pool_addr: address,
        swapper: address,
        fa_in: FungibleAsset,
        min_out: u64,
    ): FungibleAsset {
        abort E_FROZEN
    }

    public fun swap(
        pool_addr: address, swapper: address,
        fa_in: FungibleAsset, min_out: u64,
    ): FungibleAsset {
        abort E_FROZEN
    }

    public fun swap_hooked(
        pool_addr: address, swapper: address,
        fa_in: FungibleAsset, min_out: u64, cap: &HookCap,
    ): FungibleAsset {
        abort E_FROZEN
    }

    public entry fun swap_entry(
        swapper: &signer, pool_addr: address,
        metadata_in: Object<Metadata>, amount_in: u64, min_out: u64,
    ) {
        abort E_FROZEN
    }

    fun add_liquidity_internal(
        pool: &mut Pool, pool_addr: address,
        provider: &signer, amount_a: u64, amount_b: u64,
    ) {
        abort E_FROZEN
    }

    fun remove_liquidity_internal(
        pool: &mut Pool, pool_addr: address,
        provider: &signer, lp_amount: u64,
    ) {
        abort E_FROZEN
    }

    public entry fun add_liquidity(
        provider: &signer, pool_addr: address, amount_a: u64, amount_b: u64,
    ) {
        abort E_FROZEN
    }

    public fun add_liquidity_hooked(
        provider: &signer, pool_addr: address,
        amount_a: u64, amount_b: u64, cap: &HookCap,
    ) {
        abort E_FROZEN
    }

    public entry fun remove_liquidity(
        provider: &signer, pool_addr: address, lp_amount: u64,
    ) {
        abort E_FROZEN
    }

    public fun remove_liquidity_hooked(
        provider: &signer, pool_addr: address, lp_amount: u64, cap: &HookCap,
    ) {
        abort E_FROZEN
    }

    public fun flash_borrow_hooked(
        pool_addr: address, borrower: address,
        metadata: Object<Metadata>, amount: u64,
        cap: &HookCap,
    ): (FungibleAsset, FlashReceipt) {
        abort E_FROZEN
    }

    public fun flash_repay(pool_addr: address, receipt: FlashReceipt) {
        abort E_FROZEN
    }

    public entry fun admin_force_remove_hook(
        admin: &signer, pool_addr: address,
    ) {
        abort E_FROZEN
    }

    public entry fun pause(admin: &signer, pool_addr: address) {
        abort E_FROZEN
    }

    public entry fun unpause(admin: &signer, pool_addr: address) {
        abort E_FROZEN
    }

    #[view]
    public fun reserves(pool_addr: address): (u64, u64) {
        abort E_FROZEN
    }

    #[view]
    public fun get_amount_out(pool_addr: address, amount_in: u64, a_to_b: bool): u64 {
        abort E_FROZEN
    }

    #[view]
    public fun pool_info(pool_addr: address): (u64, u64, u64, bool) {
        abort E_FROZEN
    }

    #[view]
    public fun pool_tokens(pool_addr: address): (Object<Metadata>, Object<Metadata>) {
        abort E_FROZEN
    }

    #[view]
    public fun twap(pool_addr: address): (u128, u128, u64) {
        abort E_FROZEN
    }

    #[view]
    public fun pool_hook(pool_addr: address): (Option<address>, bool) {
        abort E_FROZEN
    }

    #[view]
    public fun pending_fees(pool_addr: address): (u64, u64, u64, u64) {
        abort E_FROZEN
    }

    #[view]
    public fun fee_info(pool_addr: address): (u64, u64, u64, u64) {
        abort E_FROZEN
    }

    #[view]
    public fun protocol_config(): (address, address, address) {
        abort E_FROZEN
    }

    #[view]
    public fun pool_exists(pool_addr: address): bool {
        abort E_FROZEN
    }

    #[view]
    public fun get_amounts_out(
        pool_addrs: vector<address>,
        amounts_in: vector<u64>,
        a_to_b_flags: vector<bool>,
    ): vector<u64> {
        abort E_FROZEN
    }

    #[view]
    public fun get_amount_out_multihop(
        pool_addrs: vector<address>,
        amount_in: u64,
        a_to_b_flags: vector<bool>,
    ): u64 {
        abort E_FROZEN
    }
}
