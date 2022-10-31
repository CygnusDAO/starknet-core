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
// @title  cygnus_borrow
// @author CygnusDAO
// @notice Main borrow contract in Cygnus protocol
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// Libraries
from src.cygnus_core.libraries.safe_erc20 import SafeERC20
from src.cygnus_core.utils.context import msg_sender, address_this, block_timestamp
from src.cygnus_core.libraries.reentrancy_guard import ReentrancyGuard
from src.cygnus_core.libraries.safemath import SafeUint256

// Interfaces
from src.cygnus_core.interfaces.interface_erc20 import IERC20
from src.cygnus_core.interfaces.interface_cygnus_collateral import ICygnusCollateral
from src.cygnus_core.interfaces.interface_cygnus_altair_call import (
    ICygnusAltairCall,
    BorrowCallData,
)
from src.cygnus_core.interfaces.interface_giza_power_plant import IGizaPowerPlant

// 4. Dependencies
// A. ERC20
from src.cygnus_core.erc20 import (
    Balances,
    Transfer,
    name,
    symbol,
    decimals,
    totalSupply,
    balanceOf,
    allowance,
    approve,
    increaseAllowance,
    decreaseAllowance,
    transfer,
    transferFrom,
    mint_internal,
    Total_Supply,
    spend_allowance_internal,
    burn_internal,
)

// B. TERMINAL
from src.cygnus_core.cygnus_terminal import (
    Giza_Power_Plant,
    Total_Balance,
    total_balance,
    underlying,
    giza_power_plant,
    shuttle_id,
    Underlying,
    update_internal,
    before_withdraw_internal,
    after_deposit_internal,
    Deposit,
    Withdraw,
)

// C. CONTROL
from src.cygnus_core.cygnus_borrow_control import (
    collateral,
    cygnus_borrow_rewarder,
    exchange_rate_stored,
    reserve_factor,
    base_rate_per_second,
    multiplier_per_second,
    jump_multiplier_per_second,
    kink_utilization_rate,
    kink_multiplier,
    set_cygnus_borrow_rewarder,
    set_reserve_factor,
    set_interest_rate_model,
    Exchange_Rate_Stored,
    Reserve_Factor,
    Collateral,
)

// D. APPROVE
from src.cygnus_core.cygnus_borrow_approve import (
    borrow_allowances,
    borrow_approve,
    borrow_approve_update,
)

// E. TRACKER
from src.cygnus_core.cygnus_borrow_tracker import (
    total_reserves,
    total_borrows,
    borrow_index,
    borrow_rate,
    last_accrual_timestamp,
    get_borrow_balance,
    utilization_rate,
    supply_rate,
    Total_Reserves,
    Minted_Reserves,
    Total_Borrows,
    accrue_interest,
    cygnus_borrow_tracker_initializer,
    update_borrow_internal,
    track_borrow,
)

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     2. CUSTOM EVENTS
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// @param sender Indexed address of msg.sender (should be `Router` address)
// @param recipient Indexed address of recipient (if repay = this is address(0), if borrow `Router` address)
// @param borrower Indexed address of the borrower
// @param borrow_amount If borrow calldata, the amount of the underlying asset to be borrowed, else 0
// @param repay_amount If repay calldata, the amount of the underlying borrowed asset to be repaid, else 0
// @param account_borrows_prior Record of borrower's total borrows before this event
// @param account_borrows Record of borrower's total borrows after this event ( + borrowAmount) or ( - repayAmount)
// @param total_borrows_stored Record of the protocol's cummulative total borrows after this event.
// @custom:event Borrow Logs when an account borrows or repays
@event
func Borrow(
    sender: felt,
    recipient: felt,
    borrower: felt,
    borrow_amount: Uint256,
    repay_amount: Uint256,
    account_borrows_prior: Uint256,
    account_borrows: Uint256,
    total_borrows_stored: Uint256,
) {
}

// @param sender Address of msg.sender (should be `Router` address)
// @param borrower Address of the borrower
// @param liquidator Indexed address of the liquidator
// @param denebAmount The amount of the underlying asset to be seized
// @param repayAmount The amount of the underlying asset to be repaid (factors in liquidation incentive)
// @param accountBorrowsPrior Record of borrower's total borrows before this event
// @param accountBorrows Record of borrower's present borrows (accountBorrowsPrior + borrowAmount)
// @param totalBorrowsStored Record of the protocol's cummulative total borrows after this event
// @custom:event Liquidate Logs when an account liquidates a borrower

@event
func Liquidate(
    sender: felt,
    borrower: felt,
    liquidator: felt,
    deneb_amount: Uint256,
    repay_amount: Uint256,
    account_borrows_prior: Uint256,
    account_borrows: Uint256,
    total_borrows_stored: Uint256,
) {
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     4. CONSTRUCTOR
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

//
// Constructs the main borrow contract
//
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    return cygnus_borrow_tracker_initializer();
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     7. NON-CONSTANT FUNCTIONS
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// @param _exchange_rate The current exchange rate takign into account borrows
func mint_reserves_internal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _exchange_rate: Uint256
) -> (exchange_rate_: Uint256) {
    // read current stored exchange rate
    let (exchange_rate_last: Uint256) = Exchange_Rate_Stored.read();

    // exchange_rate_last <= _exchange_rate
    let (exchange_rate_is_last: felt) = uint256_le(exchange_rate_last, _exchange_rate);

    //
    // If exchange rate is the same as last jump to end of function and return exchange rate
    //
    jmp same_exchange_rate if exchange_rate_is_last != 0;

    // calculate new exchange rate taking reserves into account
    //
    // new_exchange_rate - (new_exchange_rate - last_exchange_rate) * reserve_factor;
    //
    let (exchange_rate_diff: Uint256) = SafeUint256.sub_le(_exchange_rate, exchange_rate_last);
    let (reserves_factor: Uint256) = Reserve_Factor.read();
    let (with_reserves_factor: Uint256) = SafeUint256.mul_fixed(
        exchange_rate_diff, reserves_factor
    );
    let (new_exchange_rate: Uint256) = SafeUint256.sub_le(_exchange_rate, with_reserves_factor);

    // Calculate new reserves if any
    //
    // new_reserves = total_reserves - minted_reserves
    //
    let (total_reserves_stored: Uint256) = Total_Reserves.read();
    let (minted_reserves_stored: Uint256) = Minted_Reserves.read();
    let (new_reserves: Uint256) = SafeUint256.sub_le(total_reserves_stored, minted_reserves_stored);

    // Return exchange rate if no new reserves to mint
    if (new_reserves.low + new_reserves.high == 0) {
        //
        // Explicit return
        //
        return (exchange_rate_=_exchange_rate);
    }

    // If reach here mint new_reserves
    let (factory: felt) = Giza_Power_Plant.read();
    let (dao_reserves: felt) = IGizaPowerPlant.dao_reserves(contract_address=factory);
    // mint reserves
    mint_internal(dao_reserves, new_reserves);

    //
    // Write minted reserves to storage
    //
    let (reserves_plus_new: Uint256) = SafeUint256.add(minted_reserves_stored, new_reserves);
    Minted_Reserves.write(value=reserves_plus_new);

    // store new exchange rate
    Exchange_Rate_Stored.write(value=new_exchange_rate);

    //
    // explicit return
    //
    return (exchange_rate_=new_exchange_rate);

    same_exchange_rate:
    return (exchange_rate_=_exchange_rate);
}

// ─────────────────────────────────────────────────── External ───────────────────────────────────────────────────────

//
// OVERRIDES
//

@external
func exchange_rate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    exchange_rate_: Uint256
) {
    alloc_locals;

    // Accrue interest before getting the exchange rate
    accrue_interest();

    // Total supply of CygLP in existence
    let (total_supply_stored: Uint256) = Total_Supply.read();

    // Check if supply is equal to 0
    let (supply_is_zero: felt) = uint256_eq(total_supply_stored, Uint256(0, 0));

    // If supply is 0, return initial exchange rate
    if (supply_is_zero == TRUE) {
        // return 1e18
        return (exchange_rate_=Uint256(10 ** 18, 0));
    }

    // Calculate the new exchange rate taking into account borrows and reserves
    //
    // newExchangeRate = (totalBalance + totalBorrows - reserves) / totalSupply
    //
    let (total_balance_stored: Uint256) = Total_Balance.read();
    let (total_borrows_stored: Uint256) = Total_Borrows.read();
    let (balance: Uint256) = SafeUint256.add(total_borrows_stored, total_borrows_stored);

    // total balance * scale / supply
    let (exchange_rate_: Uint256, _) = SafeUint256.div_fixed(
        total_balance_stored, total_supply_stored
    );

    return mint_reserves_internal(exchange_rate_);
}

// @notice Erc4626 compatible deposit function, receives assets and mints shares to the recipient
// @param assets Amount of assets to deposit to receive shares
// @param recipient The address receiving shares
// @return shares The amount of shares minted
// @custom:security non-reentrant
@external
func deposit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    assets: Uint256, recipient: felt
) -> (shares: Uint256) {
    alloc_locals;

    // lock
    ReentrancyGuard._start();

    // Accrue interest to CygDAI
    accrue_interest();

    //
    // 1. Get current exchange rate
    //
    let (current_exchange_rate: Uint256) = exchange_rate();

    //
    // 2. Calculate shares to mint
    //
    let (shares: Uint256, _) = SafeUint256.div_fixed(assets, current_exchange_rate);

    // ERORR: cant_mint_zero_shares
    with_attr error_message("cygnus_terminal__cant_mint_zero_shares({assets})") {
        // revert if assets is 0
        assert_not_zero(shares.low + shares.high);
    }

    //
    // 3. Transfer underlying asset from msg.sender to this contract
    //

    // Get underlying asset
    let (underlying: felt) = Underlying.read();

    // Transfer asset from caller
    SafeERC20.transferFrom(
        contract_address=underlying, sender=msg_sender(), recipient=address_this(), amount=assets
    );

    //
    // 4. Mint shares to recipient
    //
    mint_internal(recipient, shares);

    // internal deposit hook
    after_deposit_internal(assets, shares);

    //
    // EVENT: Deposit
    //
    Deposit.emit(msg_sender(), recipient, assets, shares);

    // Update modifier
    update_internal();

    // unlock
    ReentrancyGuard._end();

    return (shares=shares);
}

// @notice Erc4626 compatible redeem function, burns shares and returns assets
// @param shares Amount of shares to redeem to receive back  assets
// @param recipient The address of the recipient of the assets
// @param owner THe address of the owner of the shares
// @return assets The amount of assets withdrawn
// @custom:security non-reentrant
@external
func redeem{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    shares: Uint256, recipient: felt, owner: felt
) -> (assets: Uint256) {
    alloc_locals;

    // Lock
    ReentrancyGuard._start();

    // Accrue interest to CygDAI
    accrue_interest();

    //
    // 1. Check allowance from owner to msg.sender. spend_allowance_internal returns if msg_sender == owner
    //
    spend_allowance_internal(owner, msg_sender(), shares);

    //
    // 2. Get current exchange rate
    //
    let (current_exchange_rate: Uint256) = exchange_rate();

    //
    // 3. Calculate assets to withdraw
    //
    let (assets: Uint256) = SafeUint256.mul_fixed(shares, current_exchange_rate);

    //
    // ERORR: cant_redeem_zero_assets
    //
    with_attr error_message("cygnus_terminal__cant_redeem_zero_assets()") {
        // revert if assets is 0
        assert_not_zero(assets.low + assets.high);
    }

    //
    // ERROR: redeem_amount_invalid
    //
    with_attr error_message("cygnus_terminal__redeem_amount_invalid()") {
        // total_balance
        let (total_balance_stored: Uint256) = Total_Balance.read();
        // total_balance < assets
        let (total_balance_is_less: felt) = uint256_lt(total_balance_stored, assets);
        // revert if assets is more than balance
        assert total_balance_is_less = FALSE;
    }

    // strategy hook (if any)
    before_withdraw_internal(assets, shares);

    //
    // 4. Burn the shares from `owner`
    //
    burn_internal(owner, shares);

    //
    // 5. Transfer underlying asset from this contract to `recipient`
    //

    // Get underlying
    let (underlying: felt) = Underlying.read();

    // transfer assets to recipient
    SafeERC20.transfer(contract_address=underlying, recipient=recipient, amount=assets);

    //
    // EVENT: Withdraw
    //
    Withdraw.emit(msg_sender(), owner, recipient, assets, shares);

    // Update modifier
    update_internal();

    // Unlock
    ReentrancyGuard._end();

    return (assets=assets);
}


@external
func borrow{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    borrower: felt, recipient: felt, borrow_amount: Uint256, borrow_calldata: BorrowCallData
) {
    alloc_locals;

    // Lock
    ReentrancyGuard._start();

    // Accrue interest before borrow
    accrue_interest();

    //
    // 1. Get total DAI balance this contract currently holds
    //
    let (total_balance_stored: Uint256) = Total_Balance.read();

    //
    // ERROR: borrow_exceeds_balance Reverts if there is insufficient cash in the pool
    //
    with_attr error_message("cygnus_borrow__borrow_exceeds_balance({borrow_amount})") {
        // Total Balance of DAI must be >= Borrow amount
        let (borrow_amount_is_le_balance: felt) = uint256_lt(borrow_amount, total_balance_stored);
        // revert if assets is more than balance
        assert borrow_amount_is_le_balance = TRUE;
    }

    //
    // 2. Check for borrow allowance and update allowance
    //
    borrow_approve_update(owner=borrower, spender=msg_sender(), amount=borrow_amount);

    //
    // 3. Optimistically transfer DAI to `recipient`
    //
    let (underlying: felt) = Underlying.read();

    let (borrow_is_zero: felt) = uint256_eq(borrow_amount, Uint256(0, 0));

    // Check borrow amount is > 0 and transfer
    if (borrow_amount.low + borrow_amount.high != 0) {
        SafeERC20.transfer(contract_address=underlying, recipient=recipient, amount=borrow_amount);
    } else {
        // Avoid syscall revoke
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
    }

    //
    // 4. Check for leverage calldata (ie. bytes.length > 0)
    //
    if (borrow_calldata.calldata != 0) {
        // Callback to router
        ICygnusAltairCall.altair_borrow(
            contract_address=recipient,
            sender=msg_sender(),
            borrow_amount=borrow_amount,
            borrow_calldata=borrow_calldata,
        );

        // Avoid syscall revoke
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
    }

    //
    // 5. Get total DAI balance this contract holds after transfer
    //
    let (new_balance: Uint256) = IERC20.balanceOf(
        contract_address=underlying, account=address_this()
    );

    //
    // 6. Get repay amount
    //
    let (repay_amount: Uint256) = SafeUint256.sum_then_sub(
        new_balance, borrow_amount, total_balance_stored
    );

    //
    // 6. Update borrower`s snapshot
    //
    let (
        account_borrows_prior: Uint256, account_borrows: Uint256, total_borrows_stored: Uint256
    ) = update_borrow_internal(
        borrower=borrower, borrow_amount=borrow_amount, repay_amount=repay_amount
    );

    //
    // 7. If borrow_amount > repay_amount then this is a borrow transaction. Check that user has enough collateral
    //
    let (repay_is_le_borrow: felt) = uint256_le(repay_amount, borrow_amount);

    // Get Cygnus collateral address for this borrowable
    let (collateral_stored: felt) = Collateral.read();

    // Returns bool
    let (user_can_borrow: felt) = ICygnusCollateral.can_borrow(
        contract_address=collateral_stored,
        borrower=borrower,
        borrowable_token=address_this(),
        account_borrows=account_borrows,
    );

    // Assert user can borrow
    if (repay_is_le_borrow == TRUE) {
        //
        // ERROR insufficient_liquidity Reverts if `borrower` doesn't have enough collateral for `borrow_amount`
        //
        with_attr error_message("cygnus_borrow__insufficient_liquidity({borrower})") {
            assert user_can_borrow = TRUE;
        }
    }

    //
    // EVENT: Borrow
    //
    Borrow.emit(
        sender=msg_sender(),
        recipient=recipient,
        borrower=borrower,
        borrow_amount=borrow_amount,
        repay_amount=repay_amount,
        account_borrows_prior=account_borrows_prior,
        account_borrows=account_borrows,
        total_borrows_stored=total_borrows_stored,
    );

    // Update total balance of underlying
    update_internal();

    // Unlock
    ReentrancyGuard._end();

    return ();
}

@external
func liquidate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    borrower: felt, liquidator: felt
) -> (cyg_lp_amount: Uint256) {
    alloc_locals;

    ReentrancyGuard._start();

    accrue_interest();

    //
    // 1. Get underlying to calculate total balance stored vs current total balance
    //
    let (_underlying: felt) = Underlying.read();

    // Total balance stored
    let (total_balance_stored: Uint256) = Total_Balance.read();

    // Total balance current
    let (current_balance: Uint256) = IERC20.balanceOf(
        contract_address=_underlying, account=address_this()
    );

    //
    // 2. Calculate repay amount (current balance - total balance)
    //
    let (repay_amount: Uint256) = SafeUint256.sub_le(current_balance, total_balance_stored);

    //
    // 3. Get borrow balance of `borrower`
    //
    let (borrower_balance: Uint256) = get_borrow_balance(borrower=borrower);

    //
    // 4. If borrower balance < liquidate amount, then just repay borrower balance, else repay_amount
    //
    let (borrower_balance_is_lt_repay: felt) = uint256_lt(borrower_balance, repay_amount);

    local actual_repay_amount: Uint256;

    if (borrower_balance_is_lt_repay == TRUE) {
        assert actual_repay_amount = borrower_balance;
    } else {
        assert actual_repay_amount = repay_amount;
    }

    //
    // 5. Call collateral contract to seize the collateral amount
    //
    let (collateral: felt) = Collateral.read();

    // Calculate seize tokens
    let (cyg_lp_amount: Uint256) = ICygnusCollateral.seize_cyg_lp(
        contract_address=collateral,
        liquidator=liquidator,
        borrower=borrower,
        repay_amount=actual_repay_amount,
    );

    //
    // 6. Update position of `borrower` internally
    //
    let (
        account_borrows_prior: Uint256, account_borrows: Uint256, total_borrows_stored: Uint256
    ) = update_borrow_internal(
        borrower=borrower, borrow_amount=Uint256(0, 0), repay_amount=repay_amount
    );

    //
    // EVENT: Liquidate
    //
    Liquidate.emit(
        sender=msg_sender(),
        borrower=borrower,
        liquidator=liquidator,
        deneb_amount=cyg_lp_amount,
        repay_amount=repay_amount,
        account_borrows_prior=account_borrows_prior,
        account_borrows=account_borrows,
        total_borrows_stored=total_borrows_stored,
    );

    // Update total balance of underlying
    update_internal();

    // Unlock
    ReentrancyGuard._end();

    return (cyg_lp_amount=cyg_lp_amount);
}
