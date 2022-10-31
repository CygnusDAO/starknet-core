%lang starknet

from starkware.cairo.common.uint256 import Uint256
from src.cygnus_core.interfaces.interface_cygnus_altair_call import BorrowCallData

@contract_interface
namespace ICygnusBorrow {
    //
    // 1. ERC20
    //
    func name() -> (name: felt) {
    }

    func symbol() -> (symbol: felt) {
    }

    func decimals() -> (decimals: felt) {
    }

    func totalSupply() -> (total_supply: Uint256) {
    }

    func balanceOf(account: felt) -> (balance: Uint256) {
    }

    func allowance(owner: felt, spender: felt) -> (allowance: Uint256) {
    }

    func approve(spender: felt, amount: Uint256) -> (bool: felt) {
    }

    func decreaseAllowance(spender: felt, subtracted_value: Uint256) -> (bool: felt) {
    }

    func transfer(recipient: felt, amount: Uint256) -> (bool: felt) {
    }

    func transferFrom(sender: felt, recipient: felt, amount: Uint256) -> (bool: felt) {
    }

    func increaseAllowance(spender: felt, added_value: Uint256) -> (bool: felt) {
    }

    //
    // 2. Terminal
    //
    func total_balance() -> (total_balance: Uint256) {
    }

    func underlying() -> (underlying: felt) {
    }

    func giza_power_plant() -> (giza_power_plant: felt) {
    }

    func shuttle_id() -> (shuttle_id: felt) {
    }

    //
    // 3. BORROW CONTROL
    //
    func collateral() -> (collateral: felt) {
    }

    func cygnus_borrow_rewarder() -> (cygnus_borrow_rewarder: felt) {
    }

    func exchange_rate_stored() -> (exchange_rate_stored: Uint256) {
    }

    func reserve_factor() -> (reserve_factor: Uint256) {
    }

    func base_rate_per_second() -> (base_rate_per_second: Uint256) {
    }

    func multiplier_per_second() -> (multiplier_per_second: Uint256) {
    }

    func jump_multiplier_per_second() -> (jump_multiplier_per_second: Uint256) {
    }

    func kink_utilization_rate() -> (kink_utilization_rate: Uint256) {
    }

    func kink_multiplier() -> (kink_multiplier: Uint256) {
    }

    func set_cygnus_borrow_rewarder(new_cygnus_borrow_rewarder: felt) {
    }

    func set_reserve_factor(new_reserve_factor: Uint256) {
    }

    func set_interest_rate_model(
        base_rate_per_year: felt,
        multiplier_per_year: felt,
        kink_multiplier_: felt,
        kink_utilization_rate_: felt,
    ) {
    }

    //
    // 4. BORROW APPROVE
    //
    func borrow_allowances(owner: felt, spender: felt) -> (amount: Uint256) {
    }

    func borrow_approve(spender: felt, amount: Uint256) -> (bool: felt) {
    }

    //
    // 5. BORROW TRACKER
    //
    func total_reserves() -> (minted_reserves: Uint256) {
    }

    func total_borrows() -> (total_borrows: Uint256) {
    }

    func borrow_index() -> (borrow_index: Uint256) {
    }

    func borrow_rate() -> (borrow_rate: Uint256) {
    }

    func last_accrual_timestamp() -> (last_accrual_timestamp: Uint256) {
    }

    func get_borrow_balance(borrower: felt) -> (borrower_balance: Uint256) {
    }

    func utilization_rate() -> (util: Uint256) {
    }

    func supply_rate() -> (supply: Uint256) {
    }

    func track_borrow(borrower: felt) {
    }

    func accrue_interest() {
    }

    //
    // 6. BORROW
    //

    func borrow(borrower: felt, recipient: felt, borrow_amount: Uint256, borrow_data : BorrowCallData) {
    }

    func liquidate(borrower: felt, liquidator: felt) -> (cyg_lp_amount: Uint256) {
    }

    // OVERRIDES
    func exchange_rate() -> (exchange_rate_: Uint256) {
    }

    func deposit(assets: Uint256, recipient: felt) -> (shares: Uint256) {
    }

    func redeem(shares: Uint256, recipient: felt, owner: felt) -> (assets: Uint256) {
    }

}
