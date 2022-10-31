// SPDX-License-Identifier: Unlicensed
%lang starknet

// Cairo libs
from starkware.cairo.common.math import assert_lt, assert_le, assert_in_range
from starkware.cairo.common.uint256 import Uint256, uint256_check, uint256_le
from starkware.cairo.common.cairo_builtins import HashBuiltin

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
// @title  cygnus_collateral_control
// @author cygnusdao
// @notice The control contract in the collateral arm. This is the only contract that the admin should have write
//         access to. Specifically, the admin can update the debt ratios, liquidation incentives and liquidation fees
//         based on community proposals.
//
//         The constructor sets the default values for all pools deployed as follows:
//             - 95% debt ratio
//             - 2.5% liquidation incentive (liquidation fee is not written as default is 0)
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// 1. Dependencies -> cygnus_terminal
from src.cygnus_core.cygnus_terminal import cygnus_terminal_initializer

// 2. Libraries
from src.cygnus_core.libraries.math_ud58x18 import MathUD58x18
from src.cygnus_core.libraries.reentrancy_guard import ReentrancyGuard

// 3. Interfaces
from src.cygnus_core.interfaces.interface_deneb_orbiter import IDenebOrbiter
from src.cygnus_core.interfaces.interface_giza_power_plant import IGizaPowerPlant

// contract function/vars
from src.cygnus_core.cygnus_terminal import (
    cygnus_admin_internal,
    Shuttle_ID,
    Giza_Power_Plant,
    Underlying,
)

// Utils
from src.cygnus_core.utils.context import msg_sender, address_this

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     2. CUSTOM EVENTS
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

//
// @custom:event NewDebtRatio Emitted when the debt ratio is updated by admin
//
@event
func NewDebtRatio(old_debt_ratio: Uint256, new_debt_ratio: Uint256) {
}

//
// @custom:event NewLiquidationIncentive Emitted when the liquidation incentive is updated by admin
//
@event
func NewLiquidationIncentive(
    old_liquidation_incentive: Uint256, new_liquidation_incentive: Uint256
) {
}

//
// @custom:event NewLiquidationFee Emitted when the liquidation fee is updated by admin
//
@event
func NewLiquidationFee(old_liquidation_fee: Uint256, new_liquidation_fee: Uint256) {
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     3. STORAGE - INTERNAL
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// Constants

// @notice Min debt ratio = 0.8e18 = 80%
const DEBT_RATIO_MIN = 8 * (10 ** 17);

// @notice Max debt ratio = 1e18 = 100%
const DEBT_RATIO_MAX = 10 ** 18;

// @notice Min liquidation incentive = 1.00e18 = None
const LIQUIDATION_INCENTIVE_MIN = 10 ** 18;

// @notice Max liquidation incentive = 1.10e18 = 10%
const LIQUIDATION_INCENTIVE_MAX = 10 ** 18 + (10 ** 17);

// @notice Max liquidation fee = 0.1e18 = 10%
const LIQUIDATION_FEE_MAX = 10 ** 17;

// Storage vars

// @notice Address of the borrowable contract
@storage_var
func Borrowable() -> (borrowable: felt) {
}

// Address of Cygnus` LP price oracle
@storage_var
func Cygnus_Nebula_Oracle() -> (cygnus_nebula_oracle: felt) {
}

// @notice Current debt ratio set - Default: 95%
@storage_var
func Debt_Ratio() -> (debt_ratio: Uint256) {
}

// @notice Current liquidation incentive for liquidators - Default: 2.5%
@storage_var
func Liquidation_Incentive() -> (liquidation_incentive: Uint256) {
}

// @notice Current fee the protocol keeps from each liquidation - Default: 0%
@storage_var
func Liquidation_Fee() -> (liquidation_fee: Uint256) {
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//      4. CONSTRUCTOR
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

//
// @notice Constructs the collateral arm and creates the CygLP token, initializing the pool token at cygnus_terminal.
//
//         It reads the addresses the Cygnus addresses from the orbiter (factory, borrowable, underlying and pool ID)
//
//         It assigns the default:
//           - debt ratio,
//           - liquidation incentive
//           - liquidation fee
//
func cygnus_collateral_control_initializer{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    // Once factory is set, this function cannot be run again
    let (factory_deployed: felt) = Giza_Power_Plant.read();

    //
    // Safety
    //
    if (factory_deployed != 0) {
        return ();
    }

    // Get params from collateral orbiter:
    //   - Factory
    //   - Collateral
    //   - Asset
    //   - Lending Pool ID
    let (
        factory: felt, borrowable: felt, underlying: felt, shuttle_id: felt
    ) = IDenebOrbiter.get_collateral_parameters(contract_address=msg_sender());

    //
    // 1. Factory
    //
    Giza_Power_Plant.write(factory);

    // 
    // 2. Borrowable
    Borrowable.write(borrowable);

    //
    // 3. This pool's collateral token (an LP Token)
    //
    Underlying.write(underlying);

    //
    // 4. This lending pool ID (shared same ID with borrowable contract)
    //
    Shuttle_ID.write(shuttle_id);

    // Read latest oracle from factory
    let (cygnus_oracle: felt) = IGizaPowerPlant.cygnus_nebula_oracle(contract_address=factory);

    //
    // 5. Assign oracle
    //
    Cygnus_Nebula_Oracle.write(value=cygnus_oracle);

    // pool rates

    //
    // Write default debt ratio to storage: 95%
    //
    Debt_Ratio.write(Uint256(95 * (10 ** 16), 0));

    //
    // Write default liquidation incentive to storage: 2.5%
    //
    Liquidation_Incentive.write(Uint256(1025 * (10 ** 15), 0));

    // Initialize cygnus_terminal
    return cygnus_terminal_initializer('Cygnus: Collateral', 'CygLP', 18);
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//      4. STORAGE GETTERS
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────── External ───────────────────────────────────────────────────────

// STORAGE_VARS

// @return borrowable The address of this collateral`s borrow contract which holds DAI
@view
func borrowable{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    borrowable: felt
) {
    return Borrowable.read();
}

// @return cygnus_nebula_oracle The address of the LP Oracle which calculates price of 1 unit of the underlying in DAI
@view
func cygnus_nebula_oracle{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    cygnus_nebula_oracle: felt
) {
    return Cygnus_Nebula_Oracle.read();
}

// @return debt_ratio The current ratio of loan/collateral at which an account becomes liquidatable, default 95%
@view
func debt_ratio{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    debt_ratio: Uint256
) {
    return Debt_Ratio.read();
}

// @return liquidation_incentive The profit that liquidators make, taken from the LP collateral, defaul 2.5%
@view
func liquidation_incentive{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    liquidation_incentive: Uint256
) {
    return Liquidation_Incentive.read();
}

// @return liquidation_fee The fee the protocol keeps from each liquidation, default 0%
@view
func liquidation_fee{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    liquidation_fee: Uint256
) {
    return Liquidation_Fee.read();
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//      5. CONSTANT FUNCTIONS
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────── Internal ───────────────────────────────────────────────────────

// @notice Checks for valid min/max ranges when admin updates rates
// @param min The minimum uint allowed for the variable we are updating (read from the constants)
// @param value The new value of the parameter we are updating
// @param max The maximum uint allowed for the variable (also read from constants)
func valid_range_internal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    min: felt, value: felt, max: felt
) {
    //
    // ERROR: parameter_not_in_range Avoid unless value is within min/max collateral params
    //
    with_attr error_message("collateral_control__parameter_not_in_range({min}, {value}, {max})") {
        // (0 <= value - lower < RANGE_CHECK_BOUND) and (0 <= upper - 1 - value < RANGE_CHECK_BOUND).
        // our mins and max consts are below range check bound so its fine to use here
        assert_in_range(value, min, max);
    }

    return ();
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     6. NON-CONSTANT FUNCTIONS
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────── External ───────────────────────────────────────────────────────

// @notice Admin only 👽
// @notice Sets a new debt ratio within min and max ranges allowed
// @custom:security non-reentrant
@external
func set_debt_ratio{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_debt_ratio: Uint256
) {
    // start reentrancy
    ReentrancyGuard._start();

    // check is caller is admin 👽
    cygnus_admin_internal();

    // Check if within valid range, reverts if not
    // Always low side of uint
    valid_range_internal(DEBT_RATIO_MIN, new_debt_ratio.low, DEBT_RATIO_MAX);

    // Get old debt ratio
    let (old_debt_ratio: Uint256) = debt_ratio();

    // Write debt ratio to storage
    Debt_Ratio.write(new_debt_ratio);

    //
    // EVENT: NewDebtRatio
    //
    NewDebtRatio.emit(old_debt_ratio, new_debt_ratio);

    // end reentrancy
    ReentrancyGuard._end();

    return ();
}

// @notice Admin only 👽
// @notice Sets a new liquidation incentive within min and max ranges allowed
// @custom:security non-reentrant
@external
func set_liquidation_incentive{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_liquidation_incentive: Uint256
) {
    // lock
    ReentrancyGuard._start();

    // check msg.sender
    cygnus_admin_internal();

    // check new liquidation incentive is within valid range
    valid_range_internal(
        LIQUIDATION_INCENTIVE_MIN, new_liquidation_incentive.low, LIQUIDATION_INCENTIVE_MAX
    );

    // read current liq. incentive from storage
    let (old_liquidation_incentive: Uint256) = Liquidation_Incentive.read();

    // write new liq. incentive to storage
    Liquidation_Incentive.write(value=new_liquidation_incentive);

    //
    // EVENT: NewLiquidationIncentive
    //
    NewLiquidationIncentive.emit(old_liquidation_incentive, new_liquidation_incentive);

    // unlock
    ReentrancyGuard._end();

    return ();
}

// @notice Admin only 👽
// @notice Sets a new liquidation fee within min and max ranges allowed
// @custom:security non-reentrant
@external
func set_liquidation_fee{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_liquidation_fee: Uint256
) {
    // lock
    ReentrancyGuard._start();

    // check msg.sender
    cygnus_admin_internal();

    // check is new liq. fee is within range
    valid_range_internal(0, new_liquidation_fee.low, LIQUIDATION_FEE_MAX);

    // read current liq. fee
    let (old_liquidation_fee: Uint256) = liquidation_fee();

    // store new liq. fee
    Liquidation_Fee.write(new_liquidation_fee);

    //
    // EVENT: NewLiquidationFee
    //
    NewLiquidationFee.emit(old_liquidation_fee, new_liquidation_fee);

    // unlock
    ReentrancyGuard._end();

    return ();
}
