/// Frozen. This module is deprecated and every callable function aborts.

module darbitex::pool_factory {
    use std::vector;
    use std::option::{Option};
    use aptos_std::table::{Table};
    use aptos_framework::account::{SignerCapability};
    use aptos_framework::object::Object;
    use aptos_framework::fungible_asset::Metadata;

    use darbitex::pool::{HookCap};

    const E_FROZEN: u64 = 255;

    struct Factory has key {
        signer_cap: SignerCapability,
        factory_addr: address,
        pool_count: u64,
        pool_addresses: vector<address>,
        auctions: Table<address, Auction>,
    }

    struct Auction has store, drop {
        hook_addr: address,
        bidder: address,
        bid_amount: u64,
        end_time: u64,
        is_resale: bool,
        seller: Option<address>,
        has_bid: bool,
    }

    #[event]
    struct FactoryInitialized has drop, store { factory_addr: address }

    #[event]
    struct CanonicalPoolCreated has drop, store {
        pool_addr: address, metadata_a: address, metadata_b: address, creator: address,
    }

    #[event]
    struct AuctionStarted has drop, store {
        pool_addr: address, hook_addr: address, bidder: address,
        bid_amount: u64, end_time: u64, is_resale: bool,
    }

    #[event]
    struct BidPlaced has drop, store {
        pool_addr: address, bidder: address, bid_amount: u64, hook_addr: address,
    }

    #[event]
    struct AuctionFinalized has drop, store {
        pool_addr: address, winner: address, hook_addr: address, winning_bid: u64,
    }

    #[event]
    struct AuctionCancelled has drop, store { pool_addr: address }

    #[event]
    struct HookResaleListed has drop, store {
        pool_addr: address, seller: address, min_price: u64, end_time: u64,
    }

    fun derive_pair_seed(
        metadata_a: Object<Metadata>, metadata_b: Object<Metadata>,
    ): vector<u8> {
        abort E_FROZEN
    }

    fun assert_sorted(metadata_a: Object<Metadata>, metadata_b: Object<Metadata>) {
        abort E_FROZEN
    }

    fun pool_addr_from_pair(
        factory: &Factory,
        metadata_a: Object<Metadata>, metadata_b: Object<Metadata>,
    ): address {
        abort E_FROZEN
    }

    public entry fun init_factory(deployer: &signer) {
        abort E_FROZEN
    }

    public entry fun create_canonical_pool(
        creator: &signer,
        metadata_a: Object<Metadata>,
        metadata_b: Object<Metadata>,
        amount_a: u64,
        amount_b: u64,
    ) {
        abort E_FROZEN
    }

    public entry fun start_auction(
        bidder: &signer,
        metadata_a: Object<Metadata>,
        metadata_b: Object<Metadata>,
        hook_addr: address,
        bid_amount: u64,
        duration: u64,
    ) {
        abort E_FROZEN
    }

    public entry fun bid(
        bidder: &signer,
        metadata_a: Object<Metadata>,
        metadata_b: Object<Metadata>,
        hook_addr: address,
        bid_amount: u64,
    ) {
        abort E_FROZEN
    }

    public entry fun finalize_auction(
        metadata_a: Object<Metadata>,
        metadata_b: Object<Metadata>,
    ) {
        abort E_FROZEN
    }

    public entry fun cancel_auction(
        metadata_a: Object<Metadata>,
        metadata_b: Object<Metadata>,
    ) {
        abort E_FROZEN
    }

    public fun list_for_resale(
        pool_addr: address,
        min_price: u64,
        duration: u64,
        seller: address,
        cap: &HookCap,
    ) {
        abort E_FROZEN
    }

    #[view]
    public fun factory_address(): address {
        abort E_FROZEN
    }

    #[view]
    public fun pool_count(): u64 {
        abort E_FROZEN
    }

    #[view]
    public fun canonical_pool_address(
        metadata_a: Object<Metadata>, metadata_b: Object<Metadata>,
    ): address {
        abort E_FROZEN
    }

    #[view]
    public fun has_active_auction(
        metadata_a: Object<Metadata>, metadata_b: Object<Metadata>,
    ): bool {
        abort E_FROZEN
    }

    #[view]
    public fun get_all_pools(): vector<address> {
        abort E_FROZEN
    }

    #[view]
    public fun get_pools_paginated(offset: u64, limit: u64): vector<address> {
        abort E_FROZEN
    }
}
