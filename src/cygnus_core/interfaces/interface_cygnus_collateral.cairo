%lang starknet

from starkware.cairo.common.uint256 import Uint256
from src.cygnus_core.interfaces.interface_cygnus_altair_call import RedeemCallData

@contract_interface
namespace ICygnusCollateral {
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

    func exchange_rate() -> (exchange_rate: Uint256) {
    }

    func deposit(assets: Uint256, recipient: felt) -> (shares: Uint256) {
    }

    func redeem(shares: Uint256, recipient: felt, owner: felt) -> (assets: Uint256) {
    }

    //
    // 3. COLLATERAL CONTROL
    //
    func borrowable() -> (borrowable: felt) {
    }

    func cygnus_nebula_oracle() -> (cygnus_nebula_oracle: felt) {
    }

    func debt_ratio() -> (debt_ratio: Uint256) {
    }

    func liquidation_incentive() -> (liquidation_incentive: Uint256) {
    }

    func liquidation_fee() -> (liquidation_fee: Uint256) {
    }

    func set_debt_ratio(new_debt_ratio: Uint256) {
    }

    func set_liquidation_incentive(new_liquidation_incentive: Uint256) {
    }

    func set_liquidation_fee(new_liquidation_fee: Uint256) {
    }

    //
    // 4. COLLATERAL MODEL
    //
    func get_account_liquidity(borrower: felt) -> (liquidity: Uint256, shortfall: Uint256) {
    }

    func get_lp_token_price() -> (lp_token_price: Uint256) {
    }

    func get_debt_ratio(borrower: felt) -> (borrower_debt_ratio: Uint256) {
    }

    func can_borrow(borrower: felt, borrowable_token: felt, account_borrows: Uint256) -> (
        bool: felt
    ) {
    }

    //
    // 5. COLLATERAL
    //
    func can_redeem(borrower: felt, redeem_amount: Uint256) -> (bool: felt) {
    }

    func seize_cyg_lp(liquidator: felt, borrower: felt, repay_amount: Uint256) -> (
        cyg_lp_amount: Uint256
    ) {
    }

    func flash_redeem_altair(redeemer: felt, assets: Uint256, redeem_data : RedeemCallData) {
    }
}
