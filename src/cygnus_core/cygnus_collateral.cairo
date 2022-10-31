// SPDX-License-Identifier: Unlicensed
%lang starknet

// Cairo libraries
from starkware.cairo.common.math import assert_lt, assert_not_equal, assert_not_zero
from starkware.cairo.common.uint256 import Uint256, uint256_le, uint256_lt, uint256_eq
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import FALSE, TRUE

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//
// @title  CygnusCollateral Main collateral contract
// @author CygnusDAO
// @notice This contract is responsible for seizing tokens upon liquidation and checking for redeemable amounts. It
//         also has a flash redeem function which allows anyone to redeem the underlying LP Tokens without collateral,
//         doing sanity checks at the end.
//
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

@contract_interface
namespace ICygnusBorrowTracker {
    func get_borrow_balance(borrower: felt) -> (borrowed_amount: Uint256) {
    }
}

// Libraries
from src.cygnus_core.libraries.safe_erc20 import SafeERC20
from src.cygnus_core.libraries.safemath import SafeUint256
from src.cygnus_core.libraries.reentrancy_guard import ReentrancyGuard

// Interfaces
from src.cygnus_core.interfaces.interface_giza_power_plant import IGizaPowerPlant
from src.cygnus_core.interfaces.interface_cygnus_borrow import ICygnusBorrow
from src.cygnus_core.interfaces.interface_cygnus_altair_call import (
    ICygnusAltairCall,
    RedeemCallData,
)

// Utils
from src.cygnus_core.utils.context import msg_sender, address_this

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
    transfer_internal,
    burn_internal,
    spend_allowance_internal,
    mint_internal,
)

// B. TERMINAL
from src.cygnus_core.cygnus_terminal import (
    Giza_Power_Plant,
    exchange_rate,
    total_balance,
    underlying,
    giza_power_plant,
    shuttle_id,
    update_internal,
    Total_Balance,
    Underlying,
    Withdraw,
    Deposit,
    after_deposit_internal,
    before_withdraw_internal,
)

// C. CONTROL
from src.cygnus_core.cygnus_collateral_control import (
    borrowable,
    cygnus_nebula_oracle,
    debt_ratio,
    liquidation_incentive,
    liquidation_fee,
    set_debt_ratio,
    set_liquidation_incentive,
    set_liquidation_fee,
)

// D. MODEL
from src.cygnus_core.cygnus_collateral_model import (
    Borrowable,
    Liquidation_Incentive,
    Liquidation_Fee,
    collateral_needed_internal,
    account_liquidity_internal,
    get_lp_token_price,
    can_borrow,
    cygnus_collateral_model_initializer,
    get_debt_ratio,
    get_account_liquidity,
)

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     4. CONSTRUCTOR
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

//
// @notice Constructs the main collateral contract
//
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    return cygnus_collateral_model_initializer();
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     6. CONSTANT FUNCTIONS
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// @notice Called by transferInternal to check if borrower's redeem would put their position in shortfall
// @param borrower The address of the borrower
// @param redeemAmount The amount of CygLP to redeem
// @return Whether the `borrower` account can redeem - if user has shortfall, returns false
@view
func can_redeem{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    borrower: felt, redeem_amount: Uint256
) -> (bool: felt) {
    alloc_locals;

    let (cyg_lp_balance: Uint256) = Balances.read(account=borrower);

    // return 1 if balance is less than redeem amount
    let (redeeming_above_balance: felt) = uint256_lt(cyg_lp_balance, redeem_amount);

    // return false if balance
    if (redeeming_above_balance == TRUE) {
        return (bool=FALSE);
    }

    // balance of borrower after redeeming
    let (final_balance: Uint256) = SafeUint256.sub_le(cyg_lp_balance, redeem_amount);

    // factor in current exchange rate
    let (exchange_rate_stored: Uint256) = exchange_rate();

    // get collateral amount by borrower (we adjust with LP Token price in next function)
    let (collateral_amount: Uint256) = SafeUint256.mul_fixed(final_balance, exchange_rate_stored);

    // read borrowable from storage
    let (borrowable_stored: felt) = Borrowable.read();

    // get borrowed amount by borrower
    let (borrowed_amount_dai: Uint256) = ICygnusBorrowTracker.get_borrow_balance(
        contract_address=borrowable_stored, borrower=borrower
    );

    // pass to collateral model contract, calculates lp token price here
    let (_, shortfall: Uint256) = collateral_needed_internal(
        collateral_amount, borrowed_amount_dai
    );

    // cannot be revoked - default is false
    local bool: felt;

    // check if user has no shortfall
    if (shortfall.low + shortfall.high == 0) {
        bool = TRUE;
    }

    // return bool, if shortfall is NOT zero bool defauls to false
    return (bool=bool);
}

// NEED TO OVERRIDE TRANSFER INTERNAL!!

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     7. NON-CONSTANT FUNCTIONS
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// @notice Should only be called by borrowable
@external
func seize_cyg_lp{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    liquidator: felt, borrower: felt, repay_amount: Uint256
) -> (cyg_lp_amount: Uint256) {
    alloc_locals;

    //
    // ERROR: cant_liquidate_self Avoid if the liquidator is also the borrower
    //
    with_attr error_message("collateral__cant_liquidate_self({liquidator}, {borrower})") {
        assert_not_equal(msg_sender(), borrower);
    }

    //
    // ERROR: cant_liquidate_zero Avoid unless liquidating positive amount
    //
    with_attr error_message("collateral__cant_liquidate_zero({repay_amount})") {
        assert_not_zero(repay_amount.low + repay_amount.high);
    }

    // read borrowable from storage
    let (borrowable_stored: felt) = Borrowable.read();

    //
    // ERROR: msg_sender_not_borrowable Avoid if msg sender is not borrowable contract
    //
    with_attr error_message("collateral__msg_sender_not_borrowable") {
        assert msg_sender() = borrowable_stored;
    }

    // check for shortfall
    let (liquidity: Uint256, shortfall: Uint256) = account_liquidity_internal(
        borrower, Uint256(0, 0)
    );

    //
    // ERROR: position_not_liquidatable Avoid if position does not have shortfall
    //
    with_attr error_message("collateral__position_not_liquidatable") {
        assert_not_zero(shortfall.low + shortfall.high);
    }

    // get the price of the LP Token denominated in DAI
    let (lp_token_price: Uint256) = get_lp_token_price();

    // current exchange rate of 1 cyglp to lp tokens
    let (current_exchange_rate: Uint256) = exchange_rate();

    let (liquidation_incentive_: Uint256) = Liquidation_Incentive.read();

    //
    // calculate how much CygLP to seize from the borrower and add to liquidator:
    //
    // cyg_lp_amount = (repay dai amount ÷ price of 1 LP * liquidation reward) ÷ exchange rate
    //
    let (repay_by_lp_price: Uint256, _) = SafeUint256.div_fixed(repay_amount, lp_token_price);

    let (cyg_lp_amount: Uint256) = SafeUint256.mul_div(
        repay_by_lp_price, liquidation_incentive_, current_exchange_rate
    );

    //
    // 1. update balance of borrower (balances[borrower] -= cyg_lp_amount)
    //
    let (balance_of_borrower: Uint256) = Balances.read(account=borrower);
    let (new_balance_of_borrower: Uint256) = SafeUint256.sub_le(balance_of_borrower, cyg_lp_amount);
    Balances.write(account=borrower, value=new_balance_of_borrower);

    //
    // 2. update balance of liquidator (balances[borrower] += cyg_lp_amount)
    //
    let (balance_of_liquidator: Uint256) = Balances.read(account=liquidator);
    let (new_balance_of_liquidator: Uint256) = SafeUint256.add(
        balance_of_liquidator, cyg_lp_amount
    );
    Balances.write(account=liquidator, value=new_balance_of_liquidator);

    // factor in liquidation fee into seized amount (if liq fee != 0)
    let (liquidation_fee_: Uint256) = Liquidation_Fee.read();

    let (liq_fee_is_zero: felt) = uint256_eq(liquidation_fee_, Uint256(low=0, high=0));

    jmp protocol_fee if liq_fee_is_zero != 0;

    //
    // EVENT: Transfer
    //
    Transfer.emit(from_=borrower, to=liquidator, value=cyg_lp_amount);

    // Explicit return
    return (cyg_lp_amount=cyg_lp_amount);

    //
    // Gives protocol part of the liquidation if there is a fee (default fee is 0 for all pools)
    //
    protocol_fee:
    // Factory address
    let (cygnus_fee: Uint256) = SafeUint256.mul_fixed(cyg_lp_amount, liquidation_fee_);
    let (factory: felt) = Giza_Power_Plant.read();
    let (dao_reserves: felt) = IGizaPowerPlant.dao_reserves(contract_address=factory);

    //
    // 3. update balance of borrower, must read from storage again (balances[borrower] -= cygnus_fee)
    //
    let (balance_of_borrower_after_liq: Uint256) = Balances.read(account=borrower);
    let (new_balance_of_borrower_liq_fee: Uint256) = SafeUint256.sub_le(
        balance_of_borrower_after_liq, cygnus_fee
    );
    Balances.write(account=borrower, value=new_balance_of_borrower_liq_fee);

    //
    // 4. update balance of dao reserves (balances[dao_reserves] += cygnus_fee)
    //
    let (balance_of_dao_after_liq: Uint256) = Balances.read(account=dao_reserves);
    let (new_balance_of_dao_after_liq: Uint256) = SafeUint256.sub_le(
        balance_of_dao_after_liq, cygnus_fee
    );
    Balances.write(account=borrower, value=new_balance_of_dao_after_liq);

    //
    // EVENT: Transfer
    //
    Transfer.emit(from_=borrower, to=liquidator, value=cyg_lp_amount);

    return (cyg_lp_amount=cyg_lp_amount);
}

@external
func flash_redeem_altair{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    redeemer: felt, assets: Uint256, redeem_calldata: RedeemCallData
) {
    alloc_locals;

    // Lock
    ReentrancyGuard._start();

    //
    // ERROR: cant_redeem_zero
    //
    with_attr error_message("collateral__cant_redeem_zero({redeemer}, {assets})") {
        let (assets_amount_is_zero: felt) = uint256_eq(assets, Uint256(0, 0));
        assert assets_amount_is_zero = FALSE;
    }

    //
    // ERROR: redeem_amount_invalid
    //
    with_attr error_message("collateral__redeem_amount_invalid({redeemer}, {assets})") {
        // Check redeem amount <= LP Token balance we hold
        let (total_balance_stored: Uint256) = Total_Balance.read();
        let (redeem_amount_le_balance) = uint256_le(assets, total_balance_stored);
        assert redeem_amount_le_balance = TRUE;
    }

    //
    // 1. Withdraw from strategy (if any)
    //
    before_withdraw_internal(assets, Uint256(0, 0));

    // Get underlying asset (an LP Token)
    let (underlying: felt) = Underlying.read();

    //
    // 2. Transfer assets to redeemer
    //
    SafeERC20.transfer(contract_address=underlying, recipient=redeemer, amount=assets);

    //
    // 3. Check for de-leverage calldata (ie. bytes.length > 0)
    //
    if (redeem_calldata.calldata != 0) {
        ICygnusAltairCall.altair_redeem(
            contract_address=redeemer,
            sender=msg_sender(),
            redeem_amount=assets,
            redeem_calldata=redeem_calldata,
        );

        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
    }

    //
    // 4. Calculate shares
    //
    let (cyg_lp_amount: Uint256) = Balances.read(account=address_this());
    let (exchange_rate_stored: Uint256) = exchange_rate();
    let (shares: Uint256, _) = SafeUint256.div_fixed(assets, exchange_rate_stored);

    //
    // ERROR: insufficient_redeem_amount
    //
    with_attr error_message("collateral__insufficient_redeem_amount({redeemer}, {assets})") {
        // Check if CygLP owned by this contract is < shares
        let (cyg_lp_amount_lt_shares: felt) = uint256_lt(cyg_lp_amount, shares);
        assert cyg_lp_amount_lt_shares = FALSE;
    }

    //
    // 5. Burn shares and emit {Transfer} event
    //
    burn_internal(account=address_this(), amount=cyg_lp_amount);

    // Update total balance
    update_internal();

    // Unlock
    ReentrancyGuard._end();

    return ();
}

// TERMINAL OVERRIDES

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

// @notice CygnusTerminal Override with can_redeem
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

    //
    // ERROR: insufficient_liquidity
    //
    with_attr error_message("cygnus_collateral__insufficient_liquidity({owner}, {shares})") {
        let (bool: felt) = can_redeem(owner, shares);
        assert bool = TRUE;
    }

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
