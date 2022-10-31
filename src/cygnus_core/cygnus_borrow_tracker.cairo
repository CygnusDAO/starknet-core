// SPDX-License-Identifier: Unlicensed
%lang starknet

// Cairo libraries
from starkware.cairo.common.math import assert_not_zero, assert_not_equal
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_check,
    uint256_le,
    uint256_lt,
    uint256_eq,
)
from starkware.cairo.common.cairo_builtins import HashBuiltin

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//
// @title  cygnus_borrow_tracker Contract that accrues interest to borrows/reserves and stores borrow data of each user
// @author CygnusDAO
// @notice Contract that accrues interest and tracks borrows for this shuttle. It accrues interest on any borrow,
//         liquidation or repay. The Accrue function uses 2 memory slots on each call to store reserves and borrows.
//         It is also used by CygnusCollateral contracts to get the borrow balance of each user to calculate current
//         debt ratios, liquidity or shortfall
//
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// 1. Dependencies -> cygnus_borrow_approve
from src.cygnus_core.cygnus_borrow_approve import cygnus_borrow_approve_initializer

// 2. Libraries
from src.cygnus_core.libraries.safemath import SafeUint256
from src.cygnus_core.libraries.math_ud58x18 import MathUD58x18
from src.cygnus_core.libraries.reentrancy_guard import ReentrancyGuard

// 3. Interfaces
from src.cygnus_core.interfaces.interface_cygnus_farming_pool import ICygnusFarmingPool

// 4. Utils
from src.cygnus_core.utils.context import block_timestamp

// functions/storage
from src.cygnus_core.cygnus_borrow_control import (
    Kink_Utilization_Rate,
    Multiplier_Per_Second,
    Jump_Multiplier_Per_Second,
    Base_Rate_Per_Second,
    Cygnus_Borrow_Rewarder,
    Reserve_Factor,
)

from src.cygnus_core.cygnus_terminal import Total_Balance, update_internal

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     1. CUSTOM EVENTS
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// @notice Logs when interest is accrued
// @param cashStored Total balance of this lending pool
// @param interestAccumulated Interest accumulated since last update
// @param borrowIndexStored The latest stored borrow index
// @param totalBorrowsStored Total borrow balances
// @param borrowRateStored The current borrow rate
@event
func AccrueInterest(
    cash_stored: Uint256,
    interest_accumulated: Uint256,
    borrow_index_stored: Uint256,
    total_borrows_stored: Uint256,
    borrow_rate_stored: Uint256,
) {
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     2. STRUCTS & MAPPINGS - INTERNAL
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// @custom:struct BorrowSnapshot Container for individual user's borrow balance information
// @custom:member principal Total balance (with accrued interest) as of the most recent action
// @custom:member interestIndex Global borrowIndex as of the most recent balance-changing action
struct BorrowSnapshot {
    principal: Uint256,
    interest_index: Uint256,
}

@storage_var
func Borrow_Balances(account: felt) -> (borrow_snapshot: BorrowSnapshot) {
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     3. STORAGE VARS - INTERNAL
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// @return minted_reserves The total amount of minted reserves -> used as a tracking variable to avoid querying balance_of
@storage_var
func Minted_Reserves() -> (minted_reserves: Uint256) {
}

// @return total_reserves Total DAO reserves for this pool
@storage_var
func Total_Reserves() -> (total_reserves: Uint256) {
}

// @return total_borrows The amount of total protocol borrows for this pool
@storage_var
func Total_Borrows() -> (total_borrows: Uint256) {
}

// @return borrow_index The latest borrow index
@storage_var
func Borrow_Index() -> (borrow_index: Uint256) {
}

// @return borrow_rate The borrow APR for this pool
@storage_var
func Borrow_Rate() -> (borrow_rate: Uint256) {
}

// @return last_accrual_timestamp The last time interest and reserves accrued interest
@storage_var
func Last_Accrual_Timestamp() -> (last_accrual_timestamp: Uint256) {
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     4. CONSTRUCTOR
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

//
// @notice Constructs the borrow tracker contract
//
func cygnus_borrow_tracker_initializer{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    // Set the index to one mantissa
    Borrow_Index.write(Uint256(10 ** 18, 0));

    Last_Accrual_Timestamp.write(Uint256(block_timestamp(), 0));

    return cygnus_borrow_approve_initializer();
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     5. STORAGE GETTERS - EXTERNAL
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// @notice Getter for total minted reserves owned by the DAO
@view
func total_reserves{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    minted_reserves: Uint256
) {
    return Minted_Reserves.read();
}

// @notice Getter for total borrows stored
@view
func total_borrows{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    total_borrows: Uint256
) {
    return Total_Borrows.read();
}

// @notice Getter for latest borrow index
@view
func borrow_index{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    borrow_index: Uint256
) {
    return Borrow_Index.read();
}

// @notice Getter for borrow rate (supply rate and utilization rate are functions, this must get updated
//         after accruals)
@view
func borrow_rate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    borrow_rate: Uint256
) {
    return Borrow_Rate.read();
}

// @notice Getter for the timestamp of latest accrual
@view
func last_accrual_timestamp{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    last_accrual_timestamp: Uint256
) {
    return Last_Accrual_Timestamp.read();
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     6. CONSTANT FUNCTIONS
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────── Internal ───────────────────────────────────────────────────────

// @dev This should only be accessible from the child contract CygnusBorrowTracker
// @param cash Total current balance of assets this contract holds
// @param borrows Total amount of borrowed funds
// @param reserves Total amount the protocol keeps as reserves
func get_borrow_rate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    cash: Uint256, borrows: Uint256, reserves: Uint256
) -> (current_borrow_rate: Uint256) {
    alloc_locals;

    // calculate current utilization rate
    let (cash_minus_reserves: Uint256) = SafeUint256.sum_then_sub(cash, borrows, reserves);

    let (util: Uint256, _) = SafeUint256.div_fixed(borrows, cash_minus_reserves);

    // get stored rates
    let (kink: Uint256) = Kink_Utilization_Rate.read();
    let (multiplier_per_second_stored: Uint256) = Multiplier_Per_Second.read();
    let (jump_multiplier_per_second_stored: Uint256) = Jump_Multiplier_Per_Second.read();
    let (base_rate_per_second_stored: Uint256) = Base_Rate_Per_Second.read();

    let (util_is_less: felt) = uint256_le(util, kink);

    // kink <= util
    // NORMAL RATE: util * multiplier + base rate
    //
    if (util_is_less == TRUE) {
        // slope of interest rate model when below kink kink
        let (slope: Uint256) = SafeUint256.mul_fixed(util, multiplier_per_second_stored);

        // add the base rate (if any) to the slope
        let (current_borrow_rate: Uint256) = SafeUint256.add(slope, base_rate_per_second_stored);

        // return current borrow rate
        return (current_borrow_rate=current_borrow_rate);
    }

    // util > kink
    // INCREASED RATE: (util - kink) * jump multi + normal_rate
    //
    let (kink_slope: Uint256) = SafeUint256.mul_fixed(kink, multiplier_per_second_stored);
    let (normal_rate: Uint256) = SafeUint256.add(kink_slope, base_rate_per_second_stored);

    // calculate excess utilization and add to normal rate
    let (excess_util: Uint256) = SafeUint256.sub_le(util, kink);

    // diff * jump multiplier
    let (increased_rate: Uint256) = SafeUint256.mul_fixed(
        excess_util, jump_multiplier_per_second_stored
    );

    // normal + increased
    let (current_borrow_rate: Uint256) = SafeUint256.add(increased_rate, normal_rate);

    return (current_borrow_rate=current_borrow_rate);
}

// ─────────────────────────────────────────────────── External ───────────────────────────────────────────────────────

// @notice It is used by the collateral arm to get current balances of borrowers
// @param borrower The address of the borrower
// @return borrower_balance The current DAI balance owed by the borrower
@view
func get_borrow_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    borrower: felt
) -> (borrower_balance: Uint256) {
    alloc_locals;

    let (borrower_snapshot: BorrowSnapshot) = Borrow_Balances.read(account=borrower);

    // interest index is never realistically struct.high
    if (borrower_snapshot.interest_index.low == 0) {
        return (borrower_balance=Uint256(0, 0));
    }

    // calculate borrow balance of user
    let (borrow_index_stored: Uint256) = Borrow_Index.read();

    let (borrower_balance: Uint256) = SafeUint256.mul_div(
        borrower_snapshot.principal, borrow_index_stored, borrower_snapshot.interest_index
    );

    return (borrower_balance=borrower_balance);
}

@view
func utilization_rate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    util: Uint256
) {
    alloc_locals;

    // borrows
    let (cash: Uint256) = Total_Balance.read();
    // reserves
    let (reserves: Uint256) = Total_Reserves.read();
    // cash
    let (borrows: Uint256) = Total_Borrows.read();

    // calculate current utilization rate
    let (cash_minus_reserves: Uint256) = SafeUint256.sum_then_sub(cash, borrows, reserves);

    let (util: Uint256, _) = SafeUint256.div_fixed(borrows, cash_minus_reserves);

    return (util=util);
}

@view
func supply_rate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    supply: Uint256
) {
    alloc_locals;

    // Total pool balance in terms of underlying (how much DAI this contract has)
    let (cash: Uint256) = Total_Balance.read();

    // Total DAO reserves for this pool
    let (reserves: Uint256) = Total_Reserves.read();

    // Total borrows
    let (borrows: Uint256) = Total_Borrows.read();

    // Get current borrow rate
    let (borrow_rate_stored: Uint256) = Borrow_Rate.read();

    // Get reserve factor
    let (reserve_factor: Uint256) = Reserve_Factor.read();

    // 1 - reserve_factor
    let (one_minus_reserves: Uint256) = SafeUint256.sub_le(Uint256(10 ** 18, 0), reserve_factor);
    let (rate_to_pool: Uint256) = SafeUint256.mul_fixed(borrow_rate_stored, one_minus_reserves);

    let (denom: Uint256) = SafeUint256.sum_then_sub(cash, borrows, reserves);
    let (supply: Uint256, _) = SafeUint256.div_fixed(borrows, denom);
    let (supply_adjusted: Uint256) = SafeUint256.mul_fixed(supply, rate_to_pool);

    return (supply=supply_adjusted);
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     7. NON-CONSTANT FUNCTIONS
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────── Internal ───────────────────────────────────────────────────────

// @notice Tracks individual account borrows for borrow rewards (if any)
// @param borrower The address of the borrower after updating the borrow snapshot
// @param accountBorrows Record of this borrower's total borrows up to this point
// @param borrowIndexStored Borrow index stored up to this point
func track_borrow_internal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    borrower: felt, account_borrows: Uint256, borrow_index_stored: Uint256
) {
    // Get rewarder from storage
    let (cyg_rewarder: felt) = Cygnus_Borrow_Rewarder.read();

    // Return if cyg rewarder is 0 to avoid revert
    if (cyg_rewarder == 0) {
        return ();
    }

    // Track borrow
    ICygnusFarmingPool.track_borrow(
        contract_address=cyg_rewarder,
        borrower=borrower,
        account_borrows=account_borrows,
        borrow_index_stored=borrow_index_stored,
    );

    return ();
}

// ─────────────────────────────────────────────────── External ───────────────────────────────────────────────────────

// @notice External call to track borrows for an individal borrower
// @param borrower The address of the borrower after updating the borrow snapshot
@external
func track_borrow{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(borrower: felt) {
    let (account_borrows: Uint256) = get_borrow_balance(borrower=borrower);

    let (borrow_index_stored: Uint256) = Borrow_Index.read();

    return track_borrow_internal(
        borrower=borrower, account_borrows=account_borrows, borrow_index_stored=borrow_index_stored
    );
}

// @notice Applies interest accruals to borrows and reserves
@external
func accrue_interest{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    // check when interest was last accrued
    let (current_timestamp: Uint256) = MathUD58x18.felt_to_uint256(block_timestamp());

    // stored last accrual timestamp
    let (last_accrual_timestamp_stored: Uint256) = Last_Accrual_Timestamp.read();

    let (last_accrual_was_now: felt) = uint256_eq(current_timestamp, last_accrual_timestamp_stored);

    // return if current matches last accrual timestamp
    if (last_accrual_was_now == TRUE) {
        return ();
    }

    // if we reach here then write current timestamp to storage
    Last_Accrual_Timestamp.write(value=current_timestamp);

    // get time elapsed since last accrual
    let (time_elapsed: Uint256) = SafeUint256.sub_le(
        current_timestamp, last_accrual_timestamp_stored
    );

    // ──────────────────── Load values from storage ────────────────────────────────────────────────

    // Borrows + Reserves + Cash + BorrowIndex
    let (total_borrows_stored: Uint256) = Total_Borrows.read();
    let (total_reserves_stored: Uint256) = Total_Reserves.read();
    let (cash_stored: Uint256) = Total_Balance.read();
    let (borrow_index_stored: Uint256) = Borrow_Index.read();

    // ──────────────────────────────────────────────────────────────────────────────────────────────

    // Return if no borrows
    if (total_borrows_stored.low + total_borrows_stored.high == 0) {
        return ();
    }

    // No going back, accrueeeewww

    //
    // 1. get per-second BorrowRate
    //
    let (borrow_rate_stored: Uint256) = get_borrow_rate(
        cash=cash_stored, borrows=total_borrows_stored, reserves=total_reserves_stored
    );

    //
    // 2. Multiply BorrowAPR by the time elapsed
    //
    let (interest_factor: Uint256) = SafeUint256.mul(borrow_rate_stored, time_elapsed);

    //
    // 3. Calculate the interest accumulated in this time elapsed
    //
    let (interest_accumulated: Uint256) = SafeUint256.mul_fixed(
        interest_factor, total_borrows_stored
    );

    //
    // 4. Add the interest accumulated to total borrows
    //
    let (total_borrows_stored: Uint256) = SafeUint256.add(
        total_borrows_stored, interest_accumulated
    );

    //
    // 5. Add interest to total reserves (reserveFactor * interestAccumulated / scale) + reservesStored
    //
    let (reserve_factor: Uint256) = Reserve_Factor.read();
    let (reserves_interest: Uint256) = SafeUint256.mul_fixed(reserve_factor, interest_accumulated);
    let (total_reserves_stored: Uint256) = SafeUint256.add(
        total_reserves_stored, reserves_interest
    );

    //
    // 6. Update the borrow index ( new_index = index + (interestfactor * index / 1e18) )
    //
    let (_interest_factor: Uint256) = SafeUint256.mul_fixed(interest_factor, borrow_index_stored);
    let (borrow_index_stored: Uint256) = SafeUint256.add(borrow_index_stored, _interest_factor);

    // ──────────────────── Store values to storage ────────────────────────────────────────────────

    // Borrows + Reserves + BorrowRate + BorrowIndex (cash gets updated with our modifier)
    Total_Borrows.write(total_borrows_stored);
    Total_Reserves.write(total_reserves_stored);
    Borrow_Rate.write(borrow_rate_stored);
    Borrow_Index.write(borrow_index_stored);

    // ──────────────────────────────────────────────────────────────────────────────────────────────

    //
    // EVENT: AccrueInterest
    //
    AccrueInterest.emit(
        cash_stored=cash_stored,
        interest_accumulated=interest_accumulated,
        borrow_index_stored=borrow_index_stored,
        total_borrows_stored=total_borrows_stored,
        borrow_rate_stored=borrow_rate_stored,
    );

    return ();
}

// @notice Record keeping private function for all borrows, repays and liquidations
// @param borrower Address of the borrower
// @param borrowAmount The amount of the underlying to update
// @param repayAmount The amount to repay
// @return accountBorrowsPrior Record of account's total borrows before this event
// @return accountBorrows Record of account's total borrows (accountBorrowsPrior + borrowAmount)
// @return totalBorrowsStored Record of the protocol's cummulative total borrows after this event
func update_borrow_internal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    borrower: felt, borrow_amount: Uint256, repay_amount: Uint256
) -> (account_borrows_prior: Uint256, account_borrows: Uint256, total_borrows_stored: Uint256) {
    alloc_locals;

    // Internal view function to get borrower's balance, if borrower's interestIndex = 0 it returns 0
    let (account_borrows_prior: Uint256) = get_borrow_balance(borrower=borrower);

    // Get protocol total borrows
    let (total_borrows_stored: Uint256) = Total_Borrows.read();

    // If borrow amount is the same as repay, explicit return
    let (borrow_amount_eq_repay: felt) = uint256_eq(borrow_amount, repay_amount);

    // If borrow amount == repay amount return
    if (borrow_amount_eq_repay == TRUE) {
        return (
            account_borrows_prior=account_borrows_prior,
            account_borrows=account_borrows_prior,
            total_borrows_stored=total_borrows_stored,
        );
    }

    let (borrow_index_stored: Uint256) = Borrow_Index.read();

    // ──────────────────── Increase Borrow vs Decrease Borrow Transaction ────────────────────────

    let (borrow_is_le_repay_amount: felt) = uint256_le(borrow_amount, repay_amount);

    // If borrow_amount <= repay_amount then decrease borrow, else increase
    jmp decrease_borrow if borrow_is_le_repay_amount != 0;

    // ───────────────────────────────── Increase Borrow ──────────────────────────────────────────

    //
    // 1. Get the current borrow snapshot of the borrower
    //
    let (borrow_snapshot: BorrowSnapshot) = Borrow_Balances.read(account=borrower);

    //
    // 2. calculate the borrow amount to increase
    //
    let (increase_borrow_amount: Uint256) = SafeUint256.sub_le(borrow_amount, repay_amount);

    //
    // 3. User's borrow balance + new borrow amount
    //
    let (account_borrows: Uint256) = SafeUint256.add(account_borrows_prior, increase_borrow_amount);

    //
    // 4. Update the snapshot record of the borrower's principal & present borrow index
    //
    let _borrow_snapshot = BorrowSnapshot(
        principal=account_borrows, interest_index=borrow_index_stored
    );

    // write borrower's snapshot to storage
    Borrow_Balances.write(account=borrower, value=_borrow_snapshot);

    //
    // 5. Update total protocol borrows
    //

    // total borrows stored + new borrows
    let (new_total_borrows: Uint256) = SafeUint256.add(
        total_borrows_stored, increase_borrow_amount
    );

    // Write to storage
    Total_Borrows.write(value=new_total_borrows);

    //
    // 6. Track borrower's borrows for CYG rewards (if rewarder is set)
    //
    track_borrow_internal(borrower, account_borrows, borrow_index_stored);

    //
    // explicit return
    //
    return (
        account_borrows_prior=account_borrows_prior,
        account_borrows=account_borrows,
        total_borrows_stored=total_borrows_stored,
    );

    // ───────────────────────────────── Decrease Borrow ──────────────────────────────────────────

    decrease_borrow:
    //
    // 1. Get the principal and borrow index of the borrower
    //
    let (borrow_snapshot: BorrowSnapshot) = Borrow_Balances.read(account=borrower);

    //
    // 2. calculate the borrow amount to decrease
    //
    let (decrease_borrow_amount: Uint256) = SafeUint256.sub_le(repay_amount, borrow_amount);

    // get account borrows
    let (decrease_is_le_prior_borrows: felt) = uint256_le(
        decrease_borrow_amount, account_borrows_prior
    );

    local account_borrows: Uint256;

    //
    // 3. Update the snapshot record of the borrower's principal & present borrow index
    //    fine to do a sub here, if decrease amount > account borrows then we store as 0 on next if/else
    //    avoiding a revoke
    //
    let (_account_borrows: Uint256) = SafeUint256.sub_le(
        account_borrows_prior, decrease_borrow_amount
    );

    // Calculate principal
    if (decrease_is_le_prior_borrows == TRUE) {
        assert account_borrows = _account_borrows;
    } else {
        assert account_borrows = Uint256(low=0, high=0);
    }

    // Avoid revoke
    local interest_index: Uint256;

    // if account borrows is 0, then interest index is 0, else borrow index stored
    let (account_borrows_is_0: felt) = uint256_eq(account_borrows, Uint256(0, 0));

    // If no account borrows then interest index is 0
    if (account_borrows_is_0 == TRUE) {
        assert interest_index = Uint256(low=0, high=0);
    } else {
        assert interest_index = borrow_index_stored;
    }

    //
    // 4. Update the snapshot record of the borrower's principal & present borrow index
    //
    let _borrow_snapshot = BorrowSnapshot(principal=account_borrows, interest_index=interest_index);
    Borrow_Balances.write(account=borrower, value=_borrow_snapshot);

    //
    // 5. Calculate actual decrease amount
    //
    let (actual_decrease_amount: Uint256) = SafeUint256.sub_le(
        account_borrows_prior, account_borrows
    );

    // total_borrows = total borrows stored - decrease amount
    let (decrease_is_le_borrows: felt) = uint256_le(actual_decrease_amount, total_borrows_stored);

    //
    // 6. Calculate Total protocol borrows
    // fine to do a sub here, if decrease amount > account borrows then we store as 0 on next if/else
    // avoiding a revoke
    //
    let (_total_borrows_stored: Uint256) = SafeUint256.sub_le(
        total_borrows_stored, actual_decrease_amount
    );

    // Avoid revoke
    local total_borrows_stored_: Uint256;

    // If decrease is <= total borrows then total borrows must be 0
    if (decrease_is_le_borrows == TRUE) {
        // total_borrows = total_borrows - decrease amount
        assert total_borrows_stored_ = _total_borrows_stored;
    } else {
        // total_borrows = 0
        assert total_borrows_stored_ = Uint256(low=0, high=0);
    }

    //
    // 6. Update total protocol borrows
    //
    Total_Borrows.write(total_borrows_stored_);

    //
    // 7. Track borrower's borrows for CYG rewards (if rewarder is set)
    //
    track_borrow_internal(borrower, account_borrows, borrow_index_stored);

    //
    // explicit return
    //
    return (
        account_borrows_prior=account_borrows_prior,
        account_borrows=account_borrows,
        total_borrows_stored=total_borrows_stored_,
    );
}
