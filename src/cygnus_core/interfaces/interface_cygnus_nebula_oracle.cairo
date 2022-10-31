%lang starknet

@contract_interface
namespace ICygnusNebulaOracle {
    func name() -> (name: felt) {
    }

    func symbol() -> (symbol: felt) {
    }

    func decimals() -> (decimals: felt) {
    }

    func version() -> (version: felt) {
    }

    func admin() -> (admin: felt) {
    }

    func pending_admin() -> (pending_admin: felt) {
    }

    func empiric_oracle_address() -> (empiric_oracle_address: felt) {
    }

    func aggregation_mode() -> (aggregation_mode: felt) {
    }

    func get_nebula_oracle(lp_token_pair: felt) -> (
        oracle_id: felt, initialized: felt, empiric_key_token0: felt, empiric_key_token1: felt
    ) {
    }

    func total_oracles() -> (total_oracles: felt) {
    }

    func get_dai_price() -> (dai_price: felt) {
    }

    func get_lp_token_price(lp_token_pair: felt) -> (lp_token_price: felt) {
    }

    func initialize_oracle(
        lp_token_pair: felt, empiric_key_token0: felt, empiric_key_token1: felt
    ) {
    }

    func delete_oracle(lp_token_pair: felt) {
    }

    func set_oracle_pending_admin(new_pending_admin: felt) {
    }

    func set_oracle_admin() {
    }
}
