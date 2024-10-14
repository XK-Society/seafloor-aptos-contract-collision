// File: sources/epoch.move
module crab_project::epoch {
    use aptos_framework::timestamp;

    struct EpochInfo has key {
        last_epoch: u64,
    }

    const EPOCH_DURATION: u64 = 86400; // 1 day in seconds

    const ENOT_INITIALIZED: u64 = 1;

    public fun initialize(admin: &signer) {
        move_to(admin, EpochInfo { last_epoch: 0 });
    }

    #[view]
    public fun now(): u64 {
        to_epoch(timestamp::now_seconds())
    }

    public fun duration(): u64 {
        EPOCH_DURATION
    }

    public fun to_epoch(timestamp_secs: u64): u64 {
        timestamp_secs / EPOCH_DURATION
    }

    public fun to_seconds(epoch: u64): u64 {
        epoch * EPOCH_DURATION
    }

    #[test_only]
    public fun fast_forward(epochs: u64) {
        timestamp::fast_forward_seconds(epochs * EPOCH_DURATION);
    }

    #[test_only]
    public fun initialize_for_test(admin: &signer) {
        initialize(admin);
    }
}