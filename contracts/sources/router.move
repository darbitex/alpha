/// Frozen. This module is deprecated and every callable function aborts.

module darbitex::router {
    use aptos_framework::object::Object;
    use aptos_framework::fungible_asset::Metadata;

    const E_FROZEN: u64 = 255;

    fun assert_deadline(deadline: u64) {
        abort E_FROZEN
    }

    public entry fun swap_with_deadline(
        swapper: &signer, pool_addr: address,
        metadata_in: Object<Metadata>,
        amount_in: u64, min_out: u64, deadline: u64,
    ) {
        abort E_FROZEN
    }

    public entry fun swap_wrapped_with_deadline(
        swapper: &signer, pool_addr: address,
        metadata_in: Object<Metadata>,
        amount_in: u64, min_out: u64, deadline: u64,
    ) {
        abort E_FROZEN
    }

    public entry fun swap_2hop(
        swapper: &signer, pool1_addr: address, pool2_addr: address,
        metadata_in: Object<Metadata>,
        amount_in: u64, min_out: u64, deadline: u64,
    ) {
        abort E_FROZEN
    }

    public entry fun swap_2hop_mixed(
        swapper: &signer,
        pool1_addr: address, wrapped1: bool,
        pool2_addr: address, wrapped2: bool,
        metadata_in: Object<Metadata>,
        amount_in: u64, min_out: u64, deadline: u64,
    ) {
        abort E_FROZEN
    }

    public entry fun swap_3hop(
        swapper: &signer,
        pool1_addr: address, pool2_addr: address, pool3_addr: address,
        metadata_in: Object<Metadata>,
        amount_in: u64, min_out: u64, deadline: u64,
    ) {
        abort E_FROZEN
    }

    public entry fun swap_3hop_mixed(
        swapper: &signer,
        pool1_addr: address, wrapped1: bool,
        pool2_addr: address, wrapped2: bool,
        pool3_addr: address, wrapped3: bool,
        metadata_in: Object<Metadata>,
        amount_in: u64, min_out: u64, deadline: u64,
    ) {
        abort E_FROZEN
    }
}
