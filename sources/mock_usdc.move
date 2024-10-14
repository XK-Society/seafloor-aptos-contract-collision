// File: sources/mock_usdc.move
module crab_project::mock_usdc {
    use std::string;
    use std::option;
    use std::signer;
    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;

    struct MockUSDC has key {
        mint_ref: MintRef,
        transfer_ref: TransferRef,
        burn_ref: BurnRef,
    }

    const ASSET_SYMBOL: vector<u8> = b"USDC";

    public entry fun initialize(admin: &signer) {
        let constructor_ref = &object::create_named_object(admin, ASSET_SYMBOL);
        
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            string::utf8(b"Mock USDC"),
            string::utf8(ASSET_SYMBOL),
            6, // USDC uses 6 decimal places
            string::utf8(b"http://example.com/mock_usdc_icon.png"),
            string::utf8(b"A mock USDC token for testing"),
        );

        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);
        
        let metadata_object_signer = object::generate_signer(constructor_ref);
        move_to(
            &metadata_object_signer,
            MockUSDC { mint_ref, transfer_ref, burn_ref }
        );
    }

    public entry fun mint(admin: &signer, to: address, amount: u64) acquires MockUSDC {
        let asset = get_metadata();
        let mock_usdc = authorized_borrow_refs(admin, asset);
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);
        let fa = fungible_asset::mint(&mock_usdc.mint_ref, amount);
        fungible_asset::deposit_with_ref(&mock_usdc.transfer_ref, to_wallet, fa);
    }

    #[view]
    public fun get_metadata(): Object<Metadata> {
        let asset_address = object::create_object_address(&@crab_project, ASSET_SYMBOL);
        object::address_to_object<Metadata>(asset_address)
    }

    inline fun authorized_borrow_refs(
        owner: &signer,
        asset: Object<Metadata>,
    ): &MockUSDC acquires MockUSDC {
        assert!(object::is_owner(asset, signer::address_of(owner)), 1);
        borrow_global<MockUSDC>(object::object_address(&asset))
    }
}
