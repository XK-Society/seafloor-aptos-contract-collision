module crab_project::crab_token {
    use std::string;
    use std::option;
    use std::signer;
    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct ManagedFungibleAsset has key {
        mint_ref: MintRef,
        transfer_ref: TransferRef,
        burn_ref: BurnRef,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct State has key {
        paused: bool,
    }

    const ASSET_SYMBOL: vector<u8> = b"CRAB";
    const ENOT_OWNER: u64 = 1;
    const EPAUSED: u64 = 2;



    public entry fun initialize(admin: &signer) {
        let constructor_ref = &object::create_named_object(admin, ASSET_SYMBOL);
        
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            string::utf8(b"CRAB Token"),
            string::utf8(ASSET_SYMBOL),
            8, // decimals
            string::utf8(b"http://example.com/crab_icon.png"),
            string::utf8(b"http://crab.example.com"),
        );

        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);
        
        let metadata_object_signer = object::generate_signer(constructor_ref);
        move_to(
            &metadata_object_signer,
            ManagedFungibleAsset { mint_ref, transfer_ref, burn_ref }
        );

        move_to(
            &metadata_object_signer,
            State { paused: false }
        );
    }

    #[view]
    public fun get_metadata(): Object<Metadata> {
        let asset_address = object::create_object_address(&@crab_project, ASSET_SYMBOL);
        object::address_to_object<Metadata>(asset_address)
    }

    public entry fun mint(admin: &signer, to: address, amount: u64) acquires ManagedFungibleAsset {
        let _ = admin; // Ignore the admin parameter to maintain compatibility
        let asset = get_metadata();
        let managed_fungible_asset = borrow_global<ManagedFungibleAsset>(object::object_address(&asset));
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);
        let fa = fungible_asset::mint(&managed_fungible_asset.mint_ref, amount);
        fungible_asset::deposit_with_ref(&managed_fungible_asset.transfer_ref, to_wallet, fa);
    }

    #[view]
    public fun balance(account: address): u64 {
        let metadata = get_metadata();
        fungible_asset::balance(primary_fungible_store::ensure_primary_store_exists(account, metadata))
    }

     public entry fun transfer(admin: &signer, from: address, to: address, amount: u64) acquires ManagedFungibleAsset, State {
        let _ = admin; // Ignore the admin parameter to maintain compatibility
        assert_not_paused();
        let asset = get_metadata();
        let transfer_ref = &borrow_global<ManagedFungibleAsset>(object::object_address(&asset)).transfer_ref;
        let from_wallet = primary_fungible_store::primary_store(from, asset);
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);
        let fa = fungible_asset::withdraw_with_ref(transfer_ref, from_wallet, amount);
        fungible_asset::deposit_with_ref(transfer_ref, to_wallet, fa);
    }

    public entry fun burn(from: &signer, amount: u64) acquires ManagedFungibleAsset {
        let asset = get_metadata();
        let managed_fungible_asset = borrow_global<ManagedFungibleAsset>(object::object_address(&asset));
        let from_wallet = primary_fungible_store::primary_store(signer::address_of(from), asset);
        fungible_asset::burn_from(&managed_fungible_asset.burn_ref, from_wallet, amount);
    }

    public entry fun set_pause(admin: &signer, paused: bool) acquires State {
        let asset = get_metadata();
        assert!(object::is_owner(asset, signer::address_of(admin)), ENOT_OWNER);
        let state = borrow_global_mut<State>(object::object_address(&asset));
        state.paused = paused;
    }

    fun assert_not_paused() acquires State {
        let state = borrow_global<State>(object::create_object_address(&@crab_project, ASSET_SYMBOL));
        assert!(!state.paused, EPAUSED);
    }

    #[test_only]
    public fun initialize_for_test(admin: &signer) {
        initialize(admin);
    }
}