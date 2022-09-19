%lang starknet

@contract_interface
namespace ICygnusNebulaOracle {
    // @return name The name of this oracle contract (`cygnus_nebula_oracle`)
    func name() -> (name: felt) {
    }

    // @return symbol The symbol used for this oracle contract (`CygNebula`)
    func symbol() -> (symbol: felt) {
    }

    // @return decimals The number of decimals used to get its user representation.
    func decimals() -> (decimals: felt) {
    }

    // @return version The version of this deployed oracle (in case we deploy more than 1)
    func version() -> (version: felt) {
    }

    // @return admin The address of this oracle's admin, with unique privileges to init oracles, delete, etc.
    func admin() -> (admin: felt) {
    }

    // @return pending_admin The address of the account pending to be the new admin (if none, then returns 0)
    func pending_admin() -> (pending_admin: felt) {
    }

    // @return empiric_oracle_address The address Empiric's oracle to get the latest price feeds for underlying assets
    func empiric_oracle_address() -> (empiric_oracle_address: felt) {
    }

    // @return aggregation_mode The mode we use from Empiric for this oracle (`Median`)
    func aggregation_mode() -> (aggregation_mode: felt) {
    }

    // @notice Get the oracle (if it exists) of a specific LP token
    // @param lp_token_pair The address of the LP Token
    // @return oracle_id The ID of the oracle for this LP Token
    // @return initialized Whether or not this LP Token's oracle is initialized
    // @return empiric_key_token0 The key for empiric`s price feed for token0 of the LP Token
    // @return empiric_key_token1 The key for empiric`s price feed for token1 of the LP Token
    func get_price_oracle(lp_token_pair: felt) -> (
        oracle_id: felt, initialized: felt, empiric_key_token0: felt, empiric_key_token1: felt
    ) {
    }

    // @notice Total amount of initialized oracles
    func total_oracles() -> (total_oracles: felt) {
    }

    // @notice simple getter of Empiric's price for this oracle's denomination token (DAI in our case)
    func get_dai_price() -> (dai_price: felt) {
    }

    // @notice Gets the price of an lp token pair denominated in DAI
    // @param lpToken_pair The address of an LP Token
    // @return lp_token_price The price of the `lp_token_pair`
    func get_lp_token_price(lp_token_pair: felt) -> (lp_token_price: felt) {
    }

    // @notice Initializes an oracle for an LP Token pair
    // @param lp_token_pair The address of the LP Token we are initializing
    // @param empiric_key_token0 Empiric's asset key for the LP Token's token0
    // @param empiric_key_token1 Empiric's asset key for the LP Token's token0
    func initialize_oracle(
        lp_token_pair: felt, empiric_key_token0: felt, empiric_key_token1: felt
    ) {
    }

    // @notice Deletes an oracle
    // @param lp_token_pair The address of the LP Token whose oracle we are deleting
    func delete_oracle(lp_token_pair: felt) {
    }

    // @notice Sets a pending admin to be accepted as the new oracle admin
    // @param new_pending_admin The address of the soon to be new oracle admin
    func set_oracle_pending_admin(new_pending_admin: felt) {
    }

    // @notice Accepts a new admin
    func set_oracle_admin() {
    }
}
