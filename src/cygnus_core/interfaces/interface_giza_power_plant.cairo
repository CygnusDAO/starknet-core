%lang starknet

@contract_interface
namespace IGizaPowerPlant {
    //
    // @return name The name of this contract (ie `Giza Power Plant`)
    //
    func name() -> (name: felt) {
    }

    //
    // @return admin The address of the Cygnus Admin which grants special permissions in collateral/borrow contracts
    //
    func admin() -> (admin: felt) {
    }

    //
    // @return pending_admin The address of the requested account to be the new Cygnus Admin
    //
    func pending_admin() -> (pending_admin: felt) {
    }

    //
    // @return dao_reserves The address that handles Cygnus reserves from all pools
    //
    func dao_reserves() -> (dao_reserves: felt) {
    }

    //
    // @return pending_dao_reserves The address of the requested contract to be the new dao reserves
    //
    func pending_dao_reserves() -> (pending_dao_reserves: felt) {
    }

    //
    // @return cygnus_nebula_oracle The address of the Cygnus price oracle
    //
    func cygnus_nebula_oracle() -> (cygnus_nebula_oracle: felt) {
    }

    //
    // @return dai The address of DAI
    //
    func dai() -> (dai: felt) {
    }

    //
    // @return native_token The address of the native token (ie WETH)
    //
    func native_token() -> (native_token: felt) {
    }

    //
    // @notice Official record of all obiters deployed
    // @param orbiterId The ID of the orbiter deployed
    // @return initialized Whether or not these orbiters are active and usable
    // @return orbiter_id The ID for these orbiters (ideally should be 1 per dex)
    // @return orbiter_name The name of the dex
    // @return albireo_orbiter The address of the borrow deployer contract
    // @return deneb_orbiter The address of the collateral deployer contract
    //
    func all_orbiters(orbiter_id: felt) -> (
        initialized: felt,
        orbiter_id: felt,
        orbiter_name: felt,
        albireo_orbiter: felt,
        deneb_orbiter: felt,
    ) {
    }

    //
    // @return total_orbiters The total number of orbiter pairs deployed (1 collateral + 1 borrow = 1 orbiter)
    //
    func total_orbiters() -> (total_orbiters: felt) {
    }

    //
    // @return shuttles_deployed The total number of lending pools deployed by this factory
    //
    func total_shuttles() -> (total_shuttles: felt) {
    }

    //
    // @notice Official record of all lending pools deployed
    // @param lpTokenPair The address of the LP Token
    // @param orbiterId The ID of the orbiter for this LP Token
    // @return launched Whether this pair exists or not
    // @return shuttle_id The ID of this shuttle
    // @return borrowable The address of the borrow contract
    // @return collateral The address of the collateral contract
    // @return orbiter_id The ID of the orbiters used to deploy this lending pool
    //
    func get_shuttle(lp_token_pair: felt, orbiter_id: felt) -> (
        launched: felt, shuttle_id: felt, borrowable: felt, collateral: felt, orbiter_id: felt
    ) {
    }

    //
    // @notice Official record of all lending pools deployed
    // @param shuttle_id The ID of the lending pool
    // @return launched Whether this pair exists or not
    // @return shuttle_id The ID of this shuttle
    // @return borrowable The address of the borrow contract
    // @return collateral The address of the collateral contract
    // @return orbiter_id The ID of the orbiters used to deploy this lending pool
    //
    func all_shuttles(shuttle_id: felt) -> (
        launched: felt, shuttle_id: felt, borrowable: felt, collateral: felt, orbiter_id: felt
    ) {
    }

    //
    // @notice Initializes both Borrow arms and the collateral arm
    // @param lp_token_pair The address of the underlying LP Token this pool is for
    // @param orbiter_id The ID of the orbiters we want to deploy to (= dex Id)
    // @param base_rate_per_year The interest rate model's base rate this shuttle uses
    // @param multiplier_per_year The multiplier this shuttle uses for calculating the interest rate
    // @return borrowable The address of the Cygnus borrow contract for this pool
    // @return collateral The address of the Cygnus collateral contract for both borrow tokens
    // @custom:security non-reentrant
    //
    func deploy_shuttle(
        lp_token_pair: felt, orbiter_id: felt, base_rate_per_year: felt, multiplier_per_year: felt
    ) -> (borrowable: felt, collateral: felt) {
    }

    //
    // @notice Sets the new orbiters to deploy collateral and borrow contracts and stores orbiters in storage
    // @param name The name of the strategy OR the dex these orbiters are for
    // @param albireo_orbiter the address of this orbiter's borrow deployer
    // @param deneb_orbiter The address of this orbiter's collateral deployer
    // @custom:security non-reentrant
    //
    func initialize_orbiters(name: felt, albireo_orbiter: felt, deneb_orbiter: felt) {
    }

    //
    // @notice 👽
    // @notice Sets a new pending admin for Cygnus
    // @param newCygnusAdmin Address of the requested Cygnus admin
    //
    func set_pending_admin(new_pending_admin: felt) {
    }

    //
    // @notice 👽
    // @notice Approves the pending admin and is the new Cygnus admin
    //
    func set_admin() {
    }

    //
    // @notice 👽
    // @notice Sets a new price oracle
    // @param new_cygnus_oracle address of the new price oracle
    //
    func set_new_cygnus_oracle(new_cygnus_oracle: felt) {
    }
}
