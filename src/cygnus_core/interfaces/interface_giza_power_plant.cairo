// : felt SPDX-License-Identifier: Unlicensed
%lang starknet

// @notice Struct of `Orbiters` which the factory calls to deploy lending pools (borrowable + collateral contracts)
// @custom:struct Orbiter Official record of all orbiter addresses held by this factory
// @custom:member initialized Whether or not this orbiter is active
// @custom:member orbiter_id The unique ID of the orbiter pair
// @custom:member orbiter_name A short string to easily identify what the orbiters were for (ie. dex name)
// @custom:member collateral_orbiter The address of the collateral deployer
// @custom:member borrowable_orbiter The address of the borrowable deployer
//
struct CygnusOrbiter {
    initialized: felt,
    orbiter_id: felt,
    orbiter_name: felt,
    albireo_orbiter: felt,
    deneb_orbiter: felt,
}

//
// @notice Struct of all lending pools deployed
// @custom:struct launched Whether or not this lending pool is deployed
// @custom:member shuttle_id The unique ID of this lending pool
// @custom:member borrowable The address of the borrowable contract
// @custom:member collateral The address of the collateral contract
// @custom:member orbiter The struct containing the orbiters used to deploy this lending pool (if `launched` true)
//
struct CygnusShuttle {
    launched: felt,
    shuttle_id: felt,
    borrowable: felt,
    collateral: felt,
    borrow_token: felt,
    lp_token_pair: felt,
    orbiter: CygnusOrbiter,
}

@contract_interface
namespace IGizaPowerPlant {
    // ════════════════════════════════════════════════════════════════════════════════════════════════════════════════
    //     5. STORAGE ACCESSORS
    // ════════════════════════════════════════════════════════════════════════════════════════════════════════════════

    func admin() -> (admin: felt) {
    }

    func pending_admin() -> (pending_admin: felt) {
    }

    func dao_reserves() -> (dao_reserves: felt) {
    }

    func pending_dao_reserves() -> (pending_dao_reserves: felt) {
    }

    func cygnus_nebula_oracle() -> (cygnus_nebula_oracle: felt) {
    }

    func dai() -> (dai: felt) {
    }

    func native_token() -> (native_token: felt) {
    }

    func total_orbiters() -> (total_orbiters: felt) {
    }

    func total_shuttles() -> (total_shuttles: felt) {
    }

    // Mappings for structs
    func all_orbiters(orbiter_id: felt) -> (CygnusOrbiter : CygnusOrbiter) {
    }

    // returns shuttle struct
    func all_shuttles(shuttle_id: felt) -> (CygnusShuttle: CygnusShuttle) {
    }

    // returns shuttle struct
    func get_shuttle(lp_token_pair: felt, orbiter_id: felt) -> (CygnusShuttle: CygnusShuttle) {
    }

    // ════════════════════════════════════════════════════════════════════════════════════════════════════════════════
    //     7. NON-CONSTANT FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════════════════════════════

    func initialize_orbiters(name: felt, albireo_orbiter: felt, deneb_orbiter: felt) {
    }

    func deploy_shuttle(lp_token_pair: felt, orbiter_id: felt) -> (
        borrowable: felt, collateral: felt
    ) {
    }
}
