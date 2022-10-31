// SPDX-License-Identifier: Unlicensed
%lang starknet

// Cairo libs
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero, assert_lt
from starkware.cairo.common.bool import FALSE, TRUE

// uint256
from starkware.cairo.common.uint256 import Uint256, uint256_check, uint256_not, uint256_eq

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
// @title  Cygnus Terminal
// @author CygnusDAO
// @notice Main contract in Cygnus for deposits and withdrawals of assets. For collateral contracts the terminal
//         accepts LP deposits and mints a pool token called `CygLP`. For borrow contracts the terminal accepts
//         DAI deposits and mints a pool token called `CygDAI`.
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// Libraries
from src.cygnus_core.libraries.math_ud58x18 import MathUD58x18
from src.cygnus_core.libraries.safemath import SafeUint256

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     1. CUSTOM EVENTS
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

@event
func Transfer(from_: felt, to: felt, value: Uint256) {
}

@event
func Approval(owner: felt, spender: felt, value: Uint256) {
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     2. STORAGE
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

@storage_var
func Name() -> (name: felt) {
}

@storage_var
func Symbol() -> (symbol: felt) {
}

@storage_var
func Decimals() -> (decimals: felt) {
}

@storage_var
func Total_Supply() -> (total_supply: Uint256) {
}

@storage_var
func Balances(account: felt) -> (balance: Uint256) {
}

@storage_var
func Allowances(owner: felt, spender: felt) -> (allowance: Uint256) {
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     3. CONSTRUCTOR
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// Constructor
func erc20_initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    name: felt, symbol: felt, decimals: felt
) {
    Name.write(name);
    Symbol.write(symbol);
    Decimals.write(decimals);
    return ();
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     4. CONSTANT FUNCTIONS
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────── External ───────────────────────────────────────────────────────

@view
func name{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (name: felt) {
    return Name.read();
}

@view
func symbol{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (symbol: felt) {
    return Symbol.read();
}

@view
func decimals{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    decimals: felt
) {
    return Decimals.read();
}

@view
func totalSupply{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    total_supply: Uint256
) {
    return Total_Supply.read();
}

@view
func balanceOf{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(account: felt) -> (
    balance: Uint256
) {
    return Balances.read(account);
}

@view
func allowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, spender: felt
) -> (allowance: Uint256) {
    return Allowances.read(owner, spender);
}

// ─────────────────────────────────────────────────── Internal ───────────────────────────────────────────────────────

func spend_allowance_internal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, spender: felt, amount: Uint256
) {
    alloc_locals;

    if (owner == spender){
      return ();
    }

    with_attr error_message("ERC20: amount is not a valid Uint256") {
        uint256_check(amount);  // almost surely not needed, might remove after confirmation
    }

    let (current_allowance: Uint256) = Allowances.read(owner, spender);
    let (infinite: Uint256) = uint256_not(Uint256(0, 0));
    let (is_infinite: felt) = uint256_eq(current_allowance, infinite);

    if (is_infinite == FALSE) {
        with_attr error_message("ERC20: insufficient allowance") {
            let (new_allowance: Uint256) = SafeUint256.sub_le(current_allowance, amount);
        }

        approve_internal(owner, spender, new_allowance);
        return ();
    }

    return ();
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     5. NON-CONSTANT FUNCTIONS
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────── External ───────────────────────────────────────────────────────

@external
func approve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    spender: felt, amount: Uint256
) -> (bool: felt) {
    // ERROR: invalid_uint256
    with_attr error_message("ERC20: amount is not a valid Uint256") {
        uint256_check(amount);
    }

    // Address of msg.sender
    let (caller) = get_caller_address();

    // Approve internally
    approve_internal(caller, spender, amount);

    return (bool=TRUE);
}

@external
func decreaseAllowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    spender: felt, subtracted_value: Uint256
) -> (bool: felt) {
    alloc_locals;

    with_attr error_message("ERC20: subtracted_value is not a valid Uint256") {
        uint256_check(subtracted_value);
    }

    let (caller) = get_caller_address();
    let (current_allowance: Uint256) = Allowances.read(owner=caller, spender=spender);

    with_attr error_message("ERC20: allowance below zero") {
        let (new_allowance: Uint256) = SafeUint256.sub_le(current_allowance, subtracted_value);
    }

    approve_internal(caller, spender, new_allowance);

    return (bool=TRUE);
}

@external
func transfer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    recipient: felt, amount: Uint256
) -> (bool: felt) {
    // Address of msg.sender
    let (sender) = get_caller_address();

    // Internal transfer
    transfer_internal(sender, recipient, amount);

    return (bool=TRUE);
}

@external
func transferFrom{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    sender: felt, recipient: felt, amount: Uint256
) -> (bool: felt) {
    let (caller) = get_caller_address();

    // subtract allowance
    spend_allowance_internal(sender, caller, amount);

    // execute transfer
    transfer_internal(sender, recipient, amount);

    return (bool=TRUE);
}

@external
func increaseAllowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    spender: felt, added_value: Uint256
) -> (bool: felt) {
    with_attr error("ERC20: added_value is not a valid Uint256") {
        uint256_check(added_value);
    }

    let (caller) = get_caller_address();
    let (current_allowance: Uint256) = Allowances.read(caller, spender);

    // add allowance
    with_attr error_message("ERC20: allowance overflow") {
        let (new_allowance: Uint256) = SafeUint256.add(current_allowance, added_value);
    }

    approve_internal(caller, spender, new_allowance);

    return (bool=TRUE);
}

// ─────────────────────────────────────────────────── Internal ───────────────────────────────────────────────────────

func approve_internal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, spender: felt, amount: Uint256
) {
    //
    // ERROR: amount_is_not_valid_uint256
    //
    with_attr error_message("ERC20: amount is not a valid Uint256") {
        uint256_check(amount);
    }

    //
    // ERROR: cannot_approve_from_zero
    //
    with_attr error_message("ERC20: cannot approve from the zero address") {
        assert_not_zero(owner);
    }

    //
    // ERROR: cannot_approve_zero
    //
    with_attr error_message("ERC20: cannot approve to the zero address") {
        assert_not_zero(spender);
    }

    Allowances.write(owner, spender, amount);

    //
    // EVENT: Approval
    //
    Approval.emit(owner, spender, amount);
    return ();
}

func transfer_internal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    sender: felt, recipient: felt, amount: Uint256
) {
    // @custom:error invalid_uint256_amount
    with_attr error_message("erc20__invalid_uint256_amount({amount})") {
        uint256_check(amount);
    }

    //
    // ERROR: transfer_sender_zero_address
    //
    with_attr error_message("erc20__transfer_sender_zero_address({sender}, {recipient})") {
        assert_not_zero(sender);
    }

    //
    // ERROR: transfer_recipient_zero_address
    //
    with_attr error_message("erc20__transfer_recipient_zero_address({sender}, {recipient})") {
        assert_not_zero(recipient);
    }

    // Read from storage
    let (sender_balance: Uint256) = Balances.read(account=sender);

    //
    // ERROR: insufficient_balance
    //
    with_attr error_message("erc20_insufficient_balance({sender}, {amount})") {
        let (new_sender_balance: Uint256) = SafeUint256.sub_le(sender_balance, amount);
    }

    // Write to storage for sender
    Balances.write(sender, new_sender_balance);

    // Add to recipient
    let (recipient_balance: Uint256) = Balances.read(account=recipient);

    // overflow is not possible because sum is guaranteed by mint to be less than total supply
    let (new_recipient_balance: Uint256) = SafeUint256.add(recipient_balance, amount);

    // Write to storage for recipient
    Balances.write(recipient, new_recipient_balance);

    //
    // EVENT: Transfer
    //
    Transfer.emit(sender, recipient, amount);

    return ();
}

func mint_internal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    recipient: felt, amount: Uint256
) {
    //
    // ERROR: invalid_uint256_amount
    //
    with_attr error_message("erc20__invalid_uint256_amount({amount})") {
        uint256_check(amount);
    }

    //
    // ERROR: mint_zero_address
    //
    with_attr error_message("erc20__mint_zero_address({recipient})") {
        assert_not_zero(recipient);
    }

    // Read from storage
    let (supply: Uint256) = Total_Supply.read();

    //
    // ERROR: mint_overflow
    //
    with_attr error_message("erc20__mint_overflow({amount})") {
        let (new_supply: Uint256) = SafeUint256.add(supply, amount);
    }

    // Write new supply to storage
    Total_Supply.write(new_supply);

    // Read from Storage
    let (balance: Uint256) = Balances.read(account=recipient);

    // overflow is not possible because sum is guaranteed to be less than total supply
    // which we check for overflow below
    let (new_balance: Uint256) = SafeUint256.add(balance, amount);

    // Write new balance to storage
    Balances.write(recipient, new_balance);

    // @custom:event Transfer
    Transfer.emit(0, recipient, amount);

    return ();
}

func burn_internal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    account: felt, amount: Uint256
) {
    // @custom:error invalid_uint256_amount
    with_attr error_message("erc20__invalid_uint256_amount({amount})") {
        uint256_check(amount);
    }

    //
    // ERROR: burn_zero_address
    //
    with_attr error_message("erc20__burn_zero_address({account})") {
        assert_not_zero(account);
    }

    // Current balance
    let (balance: Uint256) = Balances.read(account);

    //
    // ERROR: burn_amount_exceeds_balance
    //
    with_attr error_message("erc20__burn_amount_exceeds_balance()") {
        let (new_balance: Uint256) = SafeUint256.sub_le(balance, amount);
    }

    // Write to storage
    Balances.write(account, new_balance);

    // Current total supply
    let (supply: Uint256) = Total_Supply.read();

    // Substract amount from total supply
    let (new_supply: Uint256) = SafeUint256.sub_le(supply, amount);

    // Write new supply to storage
    Total_Supply.write(new_supply);

    //
    // EVENT: Transfer
    //
    Transfer.emit(account, 0, amount);

    return ();
}
