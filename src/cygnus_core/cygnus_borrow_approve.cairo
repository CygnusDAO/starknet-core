// SPDX-License-Identifier: Unlicensed
%lang starknet

// Cairo libraries
from starkware.cairo.common.math import (
    assert_not_zero,
    assert_not_equal,
    assert_250_bit,
    assert_le_felt,
)
from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.uint256 import Uint256, uint256_check, uint256_lt, uint256_le
from starkware.cairo.common.cairo_builtins import HashBuiltin

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//
// @title  cygnus_borrow_approve Main collateral contract
// @notice Contract for approving borrows for the borrow arm of the lending pool and updating borrow allowances.
//         Before any borrow, the borrower must have positive borrowAllowances set by this contract.
//
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// 1. Dependencies
from src.cygnus_core.cygnus_borrow_control import cygnus_borrow_control_initializer

// 2. Libraries
from src.cygnus_core.libraries.safemath import SafeUint256
from src.cygnus_core.libraries.math_ud58x18 import MathUD58x18

// 4. utils
from src.cygnus_core.utils.context import msg_sender, address_this, block_timestamp

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     1. CUSTOM EVENTS
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

@event
func BorrowApproval(owner: felt, spender: felt, amount: Uint256) {
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     3. STORAGE - INTERNAL
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// mapping of borrow allowances borrow_allowances[owner][spender] = amount
@storage_var
func Borrow_Allowances(owner: felt, spender: felt) -> (amount: Uint256) {
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     4. CONSTRUCTOR
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

//
// @notice Constructs the approval contract
//
func cygnus_borrow_approve_initializer{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    return cygnus_borrow_control_initializer();
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     5. STORAGE GETTERS
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// mapping getter
@view
func borrow_allowances{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, spender: felt
) -> (amount: Uint256) {
    return Borrow_Allowances.read(owner=owner, spender=spender);
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     7. NON-CONSTANT FUNCTIONS
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────── Internal ───────────────────────────────────────────────────────

// @param owner Address of the account giving the allowance
// @param spender Address of account allowed to spend `amount` of tokens
// @param amount Amount the spender is allowed to spend
func borrow_approve_internal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, spender: felt, amount: Uint256
) {
    // write allowance to storage (updated after borrow)
    Borrow_Allowances.write(owner=owner, spender=spender, value=amount);

    //
    // EVENT: BorrowApproval
    //
    BorrowApproval.emit(owner=owner, spender=spender, amount=amount);

    return ();
}


// @notice Internal function which does the sufficient checks to approve allowances
// @notice If all checks pass, call private approve function. Used by child cygnus_borrow
// @param owner Address of the owner of the tokens
// @param spender Address of the account given the allowance
// @param amount The max amount of tokens the spender can spend
func borrow_approve_update{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, spender: felt, amount: Uint256
) {
    uint256_check(amount);

    // read directly from storage
    let (current_allowance: Uint256) = Borrow_Allowances.read(owner=owner, spender=spender);

    //
    // ERROR: owner_is_spender
    //
    with_attr error_message("borrow_approve__owner_is_spender({owner}, {spender})") {
        assert_not_equal(a=owner, b=spender);
    }

    //
    // ERROR: owner_zero_address
    //
    with_attr error_message("borrow_approve__owner_zero_address({owner}, {spender})") {
        assert_not_zero(value=owner);
    }

    //
    // ERROR: spender_zero_address
    //
    with_attr error_message("borrow_approve__owner_zero_address({owner}, {spender})") {
        assert_not_zero(value=spender);
    }

    //
    // ERROR: borrow_not_allowed
    //
    with_attr error_message("borrow_approve__borrow_not_allowed({owner}, {spender}, {amount})") {
        let (amount_is_allowed : felt) = uint256_le(amount, current_allowance);
        assert amount_is_allowed = TRUE;
    }

    // reduce current allowance by amount
    let (new_amount: Uint256) = SafeUint256.sub_le(a=current_allowance, b=amount);

    // update internally with new amount
    return borrow_approve_internal(owner=owner, spender=spender, amount=new_amount);
}

// ─────────────────────────────────────────────────── External ───────────────────────────────────────────────────────

// @param spender Address of the account given the allowance
// @param amount The amount of tokens
//
@external
func borrow_approve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    spender: felt, amount: Uint256
) -> (bool: felt) {
    // do internal checks
    borrow_approve_internal(owner=msg_sender(), spender=spender, amount=amount);

    // return true if all checks pass
    return (bool=TRUE);
}
