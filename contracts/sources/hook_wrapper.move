/// Frozen. This module is deprecated and every callable function aborts.

module darbitex::hook_wrapper {
    use aptos_std::table::{Self, Table};
    use aptos_framework::object::Object;
    use aptos_framework::fungible_asset::{FungibleAsset, Metadata};

    use darbitex::pool::{HookCap, FlashReceipt};

    const E_FROZEN: u64 = 255;

    struct Witness has drop {}

    struct WrapperRegistry has key {
        caps: Table<address, HookCap>,
    }

    public entry fun init(deployer: &signer) {
        abort E_FROZEN
    }

    public entry fun register_pool(pool_addr: address) {
        abort E_FROZEN
    }

    public fun swap(
        pool_addr: address, swapper: address,
        fa_in: FungibleAsset, min_out: u64,
    ): FungibleAsset {
        abort E_FROZEN
    }

    public entry fun swap_entry(
        swapper: &signer, pool_addr: address,
        metadata_in: Object<Metadata>, amount_in: u64, min_out: u64,
    ) {
        abort E_FROZEN
    }

    public entry fun add_liquidity(
        provider: &signer, pool_addr: address,
        amount_a: u64, amount_b: u64,
    ) {
        abort E_FROZEN
    }

    public entry fun remove_liquidity(
        provider: &signer, pool_addr: address, lp_amount: u64,
    ) {
        abort E_FROZEN
    }

    public fun flash_borrow(
        pool_addr: address, borrower: address,
        metadata: Object<Metadata>, amount: u64,
    ): (FungibleAsset, FlashReceipt) {
        abort E_FROZEN
    }

    public fun flash_repay(pool_addr: address, receipt: FlashReceipt) {
        abort E_FROZEN
    }

    public entry fun withdraw_fees(
        admin: &signer, pool_addr: address,
    ) {
        abort E_FROZEN
    }

    public entry fun unregister_pool(pool_addr: address) {
        abort E_FROZEN
    }

    #[view]
    public fun is_registered(pool_addr: address): bool {
        abort E_FROZEN
    }
}
