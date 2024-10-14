module crab_project::investment_pool {
    use std::signer;
    use aptos_framework::fungible_asset::{Self, FungibleStore};
    use aptos_std::simple_map::{Self, SimpleMap};
    use crab_project::crab_token;
    use crab_project::mock_usdc;
    use crab_project::epoch;
    use aptos_framework::object::Object;
    use aptos_framework::primary_fungible_store;
    use std::vector;

    struct LiquidityPool has key {
        total_liquidity: u64,
        usdc_reserve: Object<FungibleStore>,
        investor_stakes: SimpleMap<address, u64>,
        business_stakes: SimpleMap<address, u64>,
        total_profit: u64,
        last_profit_distribution: u64,
    }

    const E_NOT_ENOUGH_BALANCE: u64 = 1;
    const E_NOT_AUTHORIZED: u64 = 2;
    const E_POOL_INSUFFICIENT_LIQUIDITY: u64 = 3;
    const E_BUSINESS_NOT_REGISTERED: u64 = 4;

    public entry fun initialize(admin: &signer) {
        let usdc_metadata = mock_usdc::get_metadata();
        let usdc_store = primary_fungible_store::ensure_primary_store_exists(signer::address_of(admin), usdc_metadata);
        
        move_to(admin, LiquidityPool { 
            total_liquidity: 0,
            usdc_reserve: usdc_store,
            investor_stakes: simple_map::create(),
            business_stakes: simple_map::create(),
            total_profit: 0,
            last_profit_distribution: 0,
        });
    }

    public entry fun register_business(admin: &signer, business: address, initial_crab_amount: u64) acquires LiquidityPool {
        assert!(signer::address_of(admin) == @crab_project, E_NOT_AUTHORIZED);
        let pool = borrow_global_mut<LiquidityPool>(@crab_project);
        
        assert!(!simple_map::contains_key(&pool.business_stakes, &business), E_BUSINESS_NOT_REGISTERED);
        
        crab_token::mint(admin, business, initial_crab_amount);
        simple_map::add(&mut pool.business_stakes, business, initial_crab_amount);
    }

    public entry fun invest(investor: &signer, business: address, amount: u64) acquires LiquidityPool {
        let investor_address = signer::address_of(investor);
        let usdc_metadata = mock_usdc::get_metadata();
        let pool = borrow_global_mut<LiquidityPool>(@crab_project);
        
        assert!(simple_map::contains_key(&pool.business_stakes, &business), E_BUSINESS_NOT_REGISTERED);
        assert!(
            fungible_asset::balance(primary_fungible_store::ensure_primary_store_exists(investor_address, usdc_metadata)) >= amount,
            E_NOT_ENOUGH_BALANCE
        );

        primary_fungible_store::transfer(investor, usdc_metadata, @crab_project, amount);

        pool.total_liquidity = pool.total_liquidity + amount;
        
        let current_stake = if (simple_map::contains_key(&pool.investor_stakes, &investor_address)) {
            *simple_map::borrow(&pool.investor_stakes, &investor_address)
        } else {
            0
        };
        simple_map::upsert(&mut pool.investor_stakes, investor_address, current_stake + amount);

        let business_stake = simple_map::borrow_mut(&mut pool.business_stakes, &business);
        *business_stake = *business_stake + amount;

        // Note: This assumes that crab_token::mint can be called by any address to mint tokens to themselves
        crab_token::mint(investor, investor_address, amount);
    }

    public entry fun divest(admin: &signer, investor: address, business: address, amount: u64) acquires LiquidityPool {
        assert!(signer::address_of(admin) == @crab_project, E_NOT_AUTHORIZED);
        let pool = borrow_global_mut<LiquidityPool>(@crab_project);
        let usdc_metadata = mock_usdc::get_metadata();
        
        assert!(simple_map::contains_key(&pool.business_stakes, &business), E_BUSINESS_NOT_REGISTERED);
        assert!(simple_map::contains_key(&pool.investor_stakes, &investor), E_NOT_ENOUGH_BALANCE);
        let current_stake = *simple_map::borrow(&pool.investor_stakes, &investor);
        assert!(current_stake >= amount, E_NOT_ENOUGH_BALANCE);
        assert!(fungible_asset::balance(pool.usdc_reserve) >= amount, E_POOL_INSUFFICIENT_LIQUIDITY);

        simple_map::upsert(&mut pool.investor_stakes, investor, current_stake - amount);
        pool.total_liquidity = pool.total_liquidity - amount;

        let business_stake = simple_map::borrow_mut(&mut pool.business_stakes, &business);
        *business_stake = *business_stake - amount;

        primary_fungible_store::transfer(admin, usdc_metadata, investor, amount);
        
        // Note: This assumes that crab_token::burn can be called by the admin to burn tokens from any address
        crab_token::burn(admin, amount);
    }

    public entry fun distribute_profits(admin: &signer, profit_amount: u64) acquires LiquidityPool {
        assert!(signer::address_of(admin) == @crab_project, E_NOT_AUTHORIZED);
        let pool = borrow_global_mut<LiquidityPool>(@crab_project);
        
        pool.total_profit = pool.total_profit + profit_amount;
        pool.last_profit_distribution = epoch::now();
    }

    public entry fun distribute_profits_to_users(admin: &signer) acquires LiquidityPool {
        assert!(signer::address_of(admin) == @crab_project, E_NOT_AUTHORIZED);
        let pool = borrow_global_mut<LiquidityPool>(@crab_project);
        
        let total_profit = pool.total_profit;
        let total_liquidity = pool.total_liquidity;

        if (total_profit > 0 && total_liquidity > 0) {
            let profit_per_token = (total_profit as u128) * 10000 / (total_liquidity as u128);
            
            let investors = simple_map::keys(&pool.investor_stakes);
            let i = 0;
            let len = vector::length(&investors);
            while (i < len) {
                let user = *vector::borrow(&investors, i);
                let user_stake = *simple_map::borrow(&pool.investor_stakes, &user);
                let user_profit = ((user_stake as u128) * profit_per_token / 10000 as u64);
                
                let new_stake = user_stake + user_profit;
                simple_map::upsert(&mut pool.investor_stakes, user, new_stake);
                i = i + 1;
            };

            pool.total_profit = 0;
            pool.last_profit_distribution = epoch::now();
        }
    }

    #[view]
    public fun total_liquidity(): u64 acquires LiquidityPool {
        borrow_global<LiquidityPool>(@crab_project).total_liquidity
    }

    #[view]
    public fun investor_stake(investor: address): u64 acquires LiquidityPool {
        let pool = borrow_global<LiquidityPool>(@crab_project);
        if (simple_map::contains_key(&pool.investor_stakes, &investor)) {
            *simple_map::borrow(&pool.investor_stakes, &investor)
        } else {
            0
        }
    }

    #[view]
    public fun business_stake(business: address): u64 acquires LiquidityPool {
        let pool = borrow_global<LiquidityPool>(@crab_project);
        if (simple_map::contains_key(&pool.business_stakes, &business)) {
            *simple_map::borrow(&pool.business_stakes, &business)
        } else {
            0
        }
    }

    #[view]
    public fun total_profit(): u64 acquires LiquidityPool {
        borrow_global<LiquidityPool>(@crab_project).total_profit
    }

    #[view]
    public fun last_profit_distribution(): u64 acquires LiquidityPool {
        borrow_global<LiquidityPool>(@crab_project).last_profit_distribution
    }

    #[view]
    public fun pool_usdc_balance(): u64 acquires LiquidityPool {
        let pool = borrow_global<LiquidityPool>(@crab_project);
        fungible_asset::balance(pool.usdc_reserve)
    }

    #[view]
    public fun user_share(user: address): u64 acquires LiquidityPool {
        let pool = borrow_global<LiquidityPool>(@crab_project);
        if (simple_map::contains_key(&pool.investor_stakes, &user)) {
            let user_stake = *simple_map::borrow(&pool.investor_stakes, &user);
            if (pool.total_liquidity > 0) {
                ((user_stake as u128) * 10000 / (pool.total_liquidity as u128) as u64)
            } else {
                0
            }
        } else {
            0
        }
    }
}