%lang starknet

@contract_interface
namespace IAlbireoOrbiter {
    func borrowable_class_hash() -> (BORROWABLE_CLASS_HASH: felt) {
    }

    //
    // @notice get borrowable params struct
    //
    func get_borrowable_parameters() -> (
        factory: felt,
        collateral: felt,
        underlying: felt,
        shuttle_id: felt,
        base_rate_per_year: felt,
        multiplier_per_year: felt,
    ) {
    }

    func deploy_borrowable(
        collateral: felt,
        underlying: felt,
        shuttle_id: felt,
        base_rate_per_year: felt,
        multiplier_per_year: felt,
    ) -> (borrowable: felt) {
    }
}
