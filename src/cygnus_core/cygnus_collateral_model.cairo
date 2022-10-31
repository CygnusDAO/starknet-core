// SPDX-License-Identifier: Unlicensed
%lang starknet

// Cairo libraries
from starkware.cairo.common.math import assert_lt, assert_not_equal, assert_not_zero
from starkware.cairo.common.uint256 import Uint256, uint256_check, uint256_le, uint256_lt
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import FALSE, TRUE

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//
// @title  CygnusCollateralModel Main contract in Cygnus that calculates a borrower's liquidity or shortfall
//         in DAI (how much LP Token the user has deposited, and then we use the oracle to return what the LP
//         Token deposited amount is worth in DAI)
// @author CygnusDAO
// @notice Theres 2 main functions to calculate the liquidity of a user: `getDebtRatio` and `getAccountLiquidity`
//         `getDebtRatio` will return the percentage of the loan divided by the user's collateral, scaled by 1e18.
//         If `getDebtRatio` returns higher than the collateral contract's max `debtRatio` then the user has shortfall
//         and can be liquidated.
//
//         The same can be calculated but instead of returning a percentage will return the actual amount of the user's
//         liquidity or shortfall but denominated in DAI, by calling `getAccountLiquidity`
//         The last function `canBorrow` is called by the `borrowable` contract (the borrow arm) to confirm if a user
//         can borrow or not.
//
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

@contract_interface
namespace ICygnusBorrowTracker {
    func get_borrow_balance(borrower: felt) -> (borrowed_amount: Uint256) {
    }
}

// 1. Interfaces
from src.cygnus_core.interfaces.interface_cygnus_nebula_oracle import ICygnusNebulaOracle

// 2. Libraries
from src.cygnus_core.libraries.safemath import SafeUint256
from src.cygnus_core.libraries.math_ud58x18 import MathUD58x18

// 3. Utils
from src.cygnus_core.utils.context import msg_sender, address_this

// parent functions/variables
from src.cygnus_core.erc20 import balanceOf
from src.cygnus_core.cygnus_terminal import exchange_rate
from src.cygnus_core.cygnus_collateral_control import (
    Borrowable,
    Cygnus_Nebula_Oracle,
    Underlying,
    Debt_Ratio,
    Liquidation_Fee,
    Liquidation_Incentive,
    cygnus_collateral_control_initializer,
)

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//      4. CONSTRUCTOR
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

//
// @notice Constructs the collateral model contract
//
func cygnus_collateral_model_initializer{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    return cygnus_collateral_control_initializer();
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//      6. CONSTANT FUNCTIONS
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────── Internal ───────────────────────────────────────────────────────

// we create for single return
func liquidation_penalty{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    penalty: Uint256
) {
    let (incentive: Uint256) = Liquidation_Incentive.read();
    let (fee: Uint256) = Liquidation_Fee.read();
    let (penalty: Uint256) = SafeUint256.add(incentive, fee);
    return (penalty=penalty);
}

// @notice Calculate collateral needed for a loan factoring in debt ratio and liq incentive
// @param collateral_amount The collateral amount the borrower has deposited (CygLP * exchangeRate)
// @param borrowed_amount The total amount of DAI the user has borrowed (CAN be 0)
// @return liquidity The account's liquidity in DAI, if any
// @return shortfall The account's shortfall in DAI, if any
func collateral_needed_internal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    collateral_amount: Uint256, borrowed_amount: Uint256
) -> (liquidity: Uint256, shortfall: Uint256) {
    alloc_locals;

    // Get the price of the underlying
    let (lp_token_price: Uint256) = get_lp_token_price();

    // read debt ratio from storage to adjust collateral (95%)
    let (debt_ratio: Uint256) = Debt_Ratio.read();

    // we adjusted with exchange rate in the previous call, deposited collateral * LP Token Price
    let (collateral_in_dai: Uint256) = SafeUint256.mul_fixed(collateral_amount, lp_token_price);

    // adjust deposited amount in DAI with debt ratio
    let (adjusted_collateral_in_dai: Uint256) = SafeUint256.mul_fixed(
        collateral_in_dai, debt_ratio
    );

    // borrowed amount in DAI * liquidation penalty
    let (penalty: Uint256) = liquidation_penalty();

    let (collateral_needed_in_dai: Uint256) = SafeUint256.mul_fixed(borrowed_amount, penalty);

    // check if collateral needed <= collateral deposited
    let (has_liquidity: felt) = uint256_le(collateral_needed_in_dai, adjusted_collateral_in_dai);

    // never underflows - REMOVE SAFE LATER
    if (has_liquidity == TRUE) {
        // collateral needed - collateral deposited
        let (liquidity: Uint256) = SafeUint256.sub_le(
            adjusted_collateral_in_dai, collateral_needed_in_dai
        );

        // return liquidity and 0 shortfall
        return (liquidity=liquidity, shortfall=Uint256(0, 0));
    } else {
        // collateral deposited - collateral needed
        let (shortfall: Uint256) = SafeUint256.sub_le(
            collateral_needed_in_dai, adjusted_collateral_in_dai
        );

        // return liquidity and 0 shortfall
        return (liquidity=Uint256(0, 0), shortfall=shortfall);
    }
}

// @notice Calculates the health of an account, returning liquidity or shortfall
// @param borrower The address of the borrower we are querying
// @param borrowed_amount
// @return liquidity The amount of borrower`s available liquidity to borrow (can borrow)
// @return shortfall The amount of borrower`s lack of funds to cover the loan (can be liquidated)
func account_liquidity_internal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    borrower: felt, borrowed_amount: Uint256
) -> (liquidity: Uint256, shortfall: Uint256) {
    alloc_locals;

    // @custom:error borrower_cant_be_zero Avoid borrower address 0
    //
    with_attr error_message("collateral_model__borrower_cant_be_zero{borrower}") {
        // check borrower not 0 address
        assert_not_zero(borrower);
    }

    // read borrowable address
    let (borrowable_stored: felt) = Borrowable.read();

    // get borrowed amount by borrower
    let (borrowed_amount: Uint256) = ICygnusBorrowTracker.get_borrow_balance(
        contract_address=borrowable_stored, borrower=borrower
    );

    // get deposited amount of LP
    let (deposited_lp_tokens: Uint256) = balanceOf(account=borrower);

    // current collateral exchange rate
    let (current_exchange_rate: Uint256) = exchange_rate();

    // adjust user deposits by current exchange rate
    let (collateral_amount: Uint256) = SafeUint256.mul_fixed(
        deposited_lp_tokens, current_exchange_rate
    );

    // return liquidity or shortfall tuple
    return collateral_needed_internal(collateral_amount, borrowed_amount);
}

// ─────────────────────────────────────────────────── External ───────────────────────────────────────────────────────

// @notice Gets an account's liquidity or shortfall
// @param borrower The address of the borrower.
// @return liquidity The account's liquidity.
// @return shortfall If user has no liquidity, return the shortfall.
@view
func get_account_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    borrower: felt
) -> (liquidity: Uint256, shortfall: Uint256) {
    // return liq or
    return account_liquidity_internal(borrower=borrower, borrowed_amount=Uint256(0, 0));
}

// @notice Gets the price of 1 LP Token of the underlying in DAI
@view
func get_lp_token_price{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    lp_token_price: Uint256
) {
   // // address of the Cygnus oracle
   let (cygnus_oracle: felt) = Cygnus_Nebula_Oracle.read();

   // address of tthis collateral`s underlying asset (an LP Token)
   let (underlying: felt) = Underlying.read();

   // Get the price of the underlying from the oracle
   let (lp_token_price_: felt) = ICygnusNebulaOracle.get_lp_token_price(
       contract_address=cygnus_oracle, lp_token_pair=underlying
   );

   // Convert LP Token price to Uint256
   let (lp_token_price: Uint256) = MathUD58x18.felt_to_uint256(lp_token_price_);

   return (lp_token_price=lp_token_price);
}

@view
func get_debt_ratio{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    borrower: felt
) -> (borrower_debt_ratio: Uint256) {
    alloc_locals;

    // address of borrowable
    let (borrowable_stored: felt) = Borrowable.read();

    // deposited amount
    let (exchange_rate_stored: Uint256) = exchange_rate();

    // get borrower's balance of CygLP
    let (balance_borrower: Uint256) = balanceOf(account=borrower);

    // factor in the exchange rate to get how much LP Tokens the user can redeem
    let (collateral_amount: Uint256) = SafeUint256.mul_fixed(
        balance_borrower, exchange_rate_stored
    );

    // get the price of the underlying
    let (lp_token_price: Uint256) = get_lp_token_price();

    // redeemable LP Tokens * price of 1 LP in DAI
    let (collateral_amount_in_dai: Uint256) = SafeUint256.mul_fixed(
        collateral_amount, lp_token_price
    );

    // get borrowed amount of DAI from borrowable
    let (borrowed_amount: Uint256) = ICygnusBorrowTracker.get_borrow_balance(
        contract_address=borrowable_stored, borrower=borrower
    );

    let (penalty: Uint256) = liquidation_penalty();

    // borrowed * penalty / scale
    let (adjusted_borrowed_amount: Uint256) = SafeUint256.mul_fixed(borrowed_amount, penalty);

    // borrowers health % = ((borrowed amount * liq incentive) / pool debt ratio)
    let (debt_ratio_stored: Uint256) = Debt_Ratio.read();

    let (adjusted_position: Uint256, _) = SafeUint256.div_fixed(
        adjusted_borrowed_amount, collateral_amount_in_dai
    );

    let (borrower_debt_ratio: Uint256, _) = SafeUint256.div_fixed(
        adjusted_position, debt_ratio_stored
    );

    // return debt ratio
    return (borrower_debt_ratio=borrower_debt_ratio);
}

// @notice Called by borrowable contract on the `borrow` function
// @param borrower The address of the borrower
// @param borrowableToken The address of the borrowable contract user wants to borrow from
// @param accountBorrows The amount the user wants to borrow
// @return Whether the account can borrow
@view
func can_borrow{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    borrower: felt, borrowable_token: felt, account_borrows: Uint256
) -> (bool: felt) {
    // get borrowable from storage
    let (borrowable_stored: felt) = Borrowable.read();

    //
    // ERROR: BorrowableInvalid
    //
    with_attr error_message("collateral_model__borrowable_invalid({borrowable_token})") {
        // check borrowable token is this collateral`s CygDAI
        assert borrowable_token = borrowable_stored;
    }

    // get borrower`s position
    let (_, shortfall: Uint256) = account_liquidity_internal(borrower, account_borrows);

    // Returns 1 if shortfall is 0
    let (shortfall_is_zero: felt) = uint256_le(shortfall, Uint256(0, 0));

    // return bool, if shortfall is NOT zero bool defauls to false
    return (bool=shortfall_is_zero);
}
