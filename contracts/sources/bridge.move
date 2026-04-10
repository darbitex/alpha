/// Frozen. This module is deprecated and every callable function aborts.

module darbitex::bridge {
    use std::vector;
    use aptos_framework::object::{Object, ExtendRef};
    use aptos_framework::fungible_asset::{FungibleAsset, Metadata};

    const E_FROZEN: u64 = 255;

    struct BridgePool has key {
        metadata_from: Object<Metadata>,
        metadata_to: Object<Metadata>,
        extend_ref: ExtendRef,
        reserve_from: u64,
        reserve_to: u64,
        lp_supply: u64,
        total_bridged: u128,
        paused: bool,
        locked: bool,
    }

    #[event]
    struct Bridged has drop, store {
        pool_addr: address, amount: u64, fee: u64, direction_from: bool,
    }

    #[event]
    struct BridgeLiquidityAdded has drop, store {
        provider: address, pool_addr: address,
        amount_from: u64, amount_to: u64, lp_minted: u64,
    }

    #[event]
    struct BridgeLiquidityRemoved has drop, store {
        provider: address, pool_addr: address,
        amount_from: u64, amount_to: u64, lp_burned: u64,
    }

    fun derive_bridge_seed(
        metadata_from: Object<Metadata>, metadata_to: Object<Metadata>,
    ): vector<u8> {
        abort E_FROZEN
    }

    public entry fun create_bridge(
        creator: &signer,
        metadata_from: Object<Metadata>,
        metadata_to: Object<Metadata>,
        amount_from: u64,
        amount_to: u64,
    ) {
        abort E_FROZEN
    }

    public fun bridge(
        pool_addr: address,
        fa_in: FungibleAsset,
        min_out: u64,
    ): FungibleAsset {
        abort E_FROZEN
    }

    public entry fun bridge_entry(
        user: &signer, pool_addr: address,
        metadata_in: Object<Metadata>, amount: u64, min_out: u64,
    ) {
        abort E_FROZEN
    }

    public entry fun add_bridge_liquidity(
        provider: &signer, pool_addr: address,
        amount_from: u64, amount_to: u64,
    ) {
        abort E_FROZEN
    }

    public entry fun remove_bridge_liquidity(
        provider: &signer, pool_addr: address, lp_amount: u64,
    ) {
        abort E_FROZEN
    }

    public entry fun pause_bridge(admin: &signer, pool_addr: address) {
        abort E_FROZEN
    }

    public entry fun unpause_bridge(admin: &signer, pool_addr: address) {
        abort E_FROZEN
    }

    #[view]
    public fun bridge_reserves(pool_addr: address): (u64, u64) {
        abort E_FROZEN
    }

    #[view]
    public fun bridge_info(pool_addr: address): (u64, u64, u64, bool) {
        abort E_FROZEN
    }

    #[view]
    public fun bridge_tokens(pool_addr: address): (Object<Metadata>, Object<Metadata>) {
        abort E_FROZEN
    }
}
