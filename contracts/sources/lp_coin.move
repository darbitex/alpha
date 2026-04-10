/// Frozen. This module is deprecated and every callable function aborts.

module darbitex::lp_coin {
    use std::signer;
    use aptos_std::table::{Self, Table};

    friend darbitex::pool;
    friend darbitex::pool_factory;
    friend darbitex::bridge;

    const E_FROZEN: u64 = 255;

    struct LPRegistry has key {
        pools: Table<address, Table<address, u64>>,
    }

    public entry fun init(deployer: &signer) {
        abort E_FROZEN
    }

    public(friend) fun mint(
        registry_addr: address,
        pool_addr: address,
        to: address,
        amount: u64,
    ) {
        abort E_FROZEN
    }

    public(friend) fun burn(
        registry_addr: address,
        pool_addr: address,
        from: address,
        amount: u64,
    ) {
        abort E_FROZEN
    }

    #[view]
    public fun balance(
        registry_addr: address,
        pool_addr: address,
        addr: address,
    ): u64 {
        abort E_FROZEN
    }
}
