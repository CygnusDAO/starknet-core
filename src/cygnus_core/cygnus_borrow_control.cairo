// SPDX-License-Identifier: Unlicensed
%lang starknet

// Cairo libraries
from starkware.cairo.common.math import (
    assert_lt,
    assert_not_equal,
    assert_in_range,
    unsigned_div_rem,
)
from starkware.cairo.common.uint256 import Uint256, uint256_check, uint256_le
from starkware.cairo.common.cairo_builtins import HashBuiltin

// Starknet syscalls
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
// @title  cygnus_borrow_control
// @author cygnusdao
// @notice The borrow control contract. This is the only contract that the admin should have write access to in the
//         borrowable arm. Specifically, the admin can update the reserve factor, the kink utilization rate and the
//         borrow tracker to reward users in CYG. The interest rate model gets updated in the next child contract.
//
//         The constructor sets the default values for all borrowable pools deployed as follows:
//             - 5% reserve factor
//             - 85% kink utilization rate
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// 1. Dependencies -> cygnus_terminal
from src.cygnus_core.cygnus_terminal import cygnus_terminal_initializer

// 2. Libraries
from src.cygnus_core.libraries.math_ud58x18 import MathUD58x18
from src.cygnus_core.libraries.reentrancy_guard import ReentrancyGuard
from src.cygnus_core.libraries.safemath import SafeUint256

// 3. Interfaces
from src.cygnus_core.interfaces.interface_albireo_orbiter import IAlbireoOrbiter

// contract funcs/vars
from src.cygnus_core.cygnus_terminal import (
    cygnus_admin_internal,
    Underlying,
    Shuttle_ID,
    Giza_Power_Plant,
)

// Utils
from src.cygnus_core.utils.context import msg_sender, address_this

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     1. CUSTOM EVENTS
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// @custom:event NewCygnusBorrowTracker Emitted when the borrow tracker is added or updated by admin
@event
func NewCygnusBorrowRewarder(old_borrow_tracker: felt, new_borrow_tracker: felt) {
}

// @param old_reserve_factor The reserve factor set until this point
// @param new_reserve_factor The new reserve factor applied from now onwards
// @custom:event NewReserveFactor Emitted when the reserve factor is updated by admin
@event
func NewReserveFactor(old_reserve_factor: Uint256, new_reserve_factor: Uint256) {
}

// @param base_rate_per_year The approximate target base APR, as a mantissa (scaled by 1e18)
// @param multiplier_per_year The rate of increase in interest rate wrt utilization (scaled by 1e18)
// @param kink_multiplier The increase to multiplier once kink utilization is reached
// @param kink_utilization_rate The rate at which the jump interest rate takes effect
// @custom:event NewInterestRateModel Logs when when the interest rate parameters are updated
@event
func NewInterestRateModel(
    base_rate_per_year: felt,
    multiplier_per_year: felt,
    kink_multiplier: felt,
    kink_utilization_rate: felt,
) {
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     3. STORAGE - INTERNAL
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// Constants

// @notice Max base rate = 0.1e18 = 10%
const BASE_RATE_MAX = 10 ** 17;

// @notice Max reserve factor = 0.2e18 = 20%
const RESERVE_FACTOR_MAX = 2 * (10 ** 17);

// @notice Min kink utilization rate for security reasons = 0.5e18 = 50%
const KINK_UTILIZATION_RATE_MIN = MathUD58x18.SCALE / 2;

// @notice Max kink utilization rate = 0.95e18 = 95%
const KINK_UTILIZATION_RATE_MAX = 95 * (10 ** 16);

// @notice The steepness once the pool reaches the kink utilization rate
const KINK_MULTIPLIER_MAX = 10;

// @notice Used to calculate the per second interest rates
const SECONDS_PER_YEAR = 31536000;

// Storage vars

// @notice Stored address of the collateral contract
@storage_var
func Collateral() -> (collateral: felt) {
}

// @notice Stored address of the contract that rewards CYG to borrowers
@storage_var
func Cygnus_Borrow_Rewarder() -> (cygnus_borrow_rewarder: felt) {
}

// @notice Stored exchange rate (takes into account borrows, unlike collateral)
@storage_var
func Exchange_Rate_Stored() -> (exchange_rate_stored: Uint256) {
}

// @notice Stored percentage that the protocol keeps as reserves from all liquidations
@storage_var
func Reserve_Factor() -> (reserve_factor: Uint256) {
}

// @notice The base interest rate which is the y-intercept when utilization rate is 0
@storage_var
func Base_Rate_Per_Second() -> (base_rate_per_second: Uint256) {
}

// @notice The multiplier of utilization rate that gives the slope of the interest rate
@storage_var
func Multiplier_Per_Second() -> (multiplier_per_second: Uint256) {
}

// @notice The multiplier per second after hitting a specified utilization point
@storage_var
func Jump_Multiplier_Per_Second() -> (jump_multiplier_per_second: Uint256) {
}

// @notice Stored kink utilization rate, (scaled by 1e18) at which the interest rate goes from gradual to steep
@storage_var
func Kink_Utilization_Rate() -> (kink_utilization_rate: Uint256) {
}

// @notice Stored kink multiplier, how steep the interest rate goes when util > kink
@storage_var
func Kink_Multiplier() -> (kink_multiplier: Uint256) {
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     3. CONSTRUCTOR
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// @notice Constructs the borrowable arm and creates the CygDai token, initializing the pool token at
//         cygnus_terminal. It writes to storage the defaul kink utilization rate, kink multiplier and the
//         reserve factor. The interest rate params are assigned in the next contract
func cygnus_borrow_control_initializer{
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

    // Get params from borrowable orbiter
    //
    // Same as collateral orbiter + Interest rate params for DAI
    let (
        factory: felt,
        collateral: felt,
        underlying: felt,
        shuttle_id: felt,
        base_rate_per_year: felt,
        multiplier_per_year: felt,
    ) = IAlbireoOrbiter.get_borrowable_parameters(contract_address=msg_sender());

    //
    // 1. Factory
    //
    Giza_Power_Plant.write(factory);

    //
    // 2. Collateral
    //
    Collateral.write(collateral);

    //
    // 3. This pool's borrowable token (DAI)
    //
    Underlying.write(underlying);

    //
    // 4. This lending pool ID (shared same ID with collateral contract)
    //
    Shuttle_ID.write(shuttle_id);

    // pool rates

    //
    // Write default reserve factor to storage: 5%
    //
    Reserve_Factor.write(Uint256(5 * (10 ** 16), 0));

    //
    // Default kink and util. get written in the interest rate model internal function
    //
    let default_kink_multiplier: felt = 2;
    let default_utilization_rate: felt = 85 * (10 ** 16);

    //
    // Make interest rate model
    //
    interest_rate_model_internal(
        base_rate_per_year, multiplier_per_year, default_kink_multiplier, default_utilization_rate
    );

    // initialize cygnus_terminal
    return cygnus_terminal_initializer('Cygnus: Borrowable', 'CygDAI', 18);
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//      4. STORAGE GETTERS
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────── External ───────────────────────────────────────────────────────

// Constants

// Storage

// @return collateral The address of this borrowable`s collateral contract that holds LP Tokens
@view
func collateral{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    collateral: felt
) {
    return Collateral.read();
}

// @return cygnus_borrow_tracker The address of the contract that rewards users in CYG
@view
func cygnus_borrow_rewarder{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    cygnus_borrow_rewarder: felt
) {
    return Cygnus_Borrow_Rewarder.read();
}

// @return exchange_rate_stored The current exchange rate stored taking into account borrows + reserves
@view
func exchange_rate_stored{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    exchange_rate_stored: Uint256
) {
    return Exchange_Rate_Stored.read();
}

// @return reserve_factor The percentage from borrows that the protocol keeps as reserves
@view
func reserve_factor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    reserve_factor: Uint256
) {
    return Reserve_Factor.read();
}

@view
func base_rate_per_second{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    base_rate_per_second: Uint256
) {
    return Base_Rate_Per_Second.read();
}

@view
func multiplier_per_second{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    multiplier_per_second: Uint256
) {
    return Multiplier_Per_Second.read();
}

@view
func jump_multiplier_per_second{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) -> (jump_multiplier_per_second: Uint256) {
    return Jump_Multiplier_Per_Second.read();
}

// @return kink_utilization_rate The point at which the interest rate goes from gradual to steep
@view
func kink_utilization_rate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    kink_utilization_rate: Uint256
) {
    return Kink_Utilization_Rate.read();
}

// @return kink_multiplier The steepness of the interest rate once util > kink
@view
func kink_multiplier{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    kink_multiplier: Uint256
) {
    return Kink_Multiplier.read();
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//      5. CONSTANT FUNCTIONS
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────── Internal ───────────────────────────────────────────────────────

// @notice Checks for valid min/max ranges when admin updates rates
// @param value The new value of the parameter we are updating
// @param min The minimum uint allowed for the variable we are updating (read from the constants)
// @param max The maximum uint allowed for the variable (also read from constants)
func valid_range_internal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    value: felt, min: felt, max: felt
) {
    //
    // ERROR: parameter_not_in_range Avoid updating value if not within min/max allowed
    //
    with_attr error_message("borrow_control__parameter_not_in_range({min}, {value}, {max})") {
        // (0 <= value - lower < RANGE_CHECK_BOUND) and (0 <= upper - 1 - value < RANGE_CHECK_BOUND).
        // our mins and max consts are below range check bound so its fine to use here
        assert_in_range(value, min, max);
    }

    return ();
}

// @notice Internal function to update the parameters of the interest rate model
// @param base_rate_per_year The approximate target base APR, as a mantissa (scaled by 1e18)
// @param multiplier_per_year The rate of increase in interest rate wrt utilization (scaled by 1e18)
// @param kink_multiplier_ The increase to farmApy once kink utilization is reached
// @param kink_utilization_rate_ The new utilization rate
func interest_rate_model_internal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    base_rate_per_year: felt,
    multiplier_per_year: felt,
    kink_multiplier_: felt,
    kink_utilization_rate_: felt,
) {
    alloc_locals;

    // check base rate is valid
    valid_range_internal(base_rate_per_year, 0, BASE_RATE_MAX);

    // check kink is within [50% - 95%]
    valid_range_internal(
        kink_utilization_rate_, KINK_UTILIZATION_RATE_MIN, KINK_UTILIZATION_RATE_MAX
    );

    // check kink multiplier is <= KINK_MULTIPLIER_MAX (10)
    valid_range_internal(kink_multiplier_, 1, KINK_MULTIPLIER_MAX);

    // 1. store base rate per second
    let (base_rate_per_second_: Uint256, _) = SafeUint256.div_rem(
        Uint256(base_rate_per_year, 0), Uint256(SECONDS_PER_YEAR, 0)
    );

    Base_Rate_Per_Second.write(value=base_rate_per_second_);

    // 2. store multiplier per second
    let (multiplier_per_second_: felt) = MathUD58x18.div_fixed(
        multiplier_per_year, SECONDS_PER_YEAR * kink_utilization_rate_
    );

    Multiplier_Per_Second.write(value=Uint256(multiplier_per_second_, 0));

    // 3. store kink multiplier and utilization rate
    Kink_Multiplier.write(value=Uint256(kink_multiplier_, 0));
    Kink_Utilization_Rate.write(value=Uint256(kink_utilization_rate_, 0));

    // 4. store jump multiplier per second
    let (jump_multiplier_per_second: felt) = MathUD58x18.mul_div(
        multiplier_per_year, kink_multiplier_, SECONDS_PER_YEAR
    );

    let (jump_multiplier_per_second_adjusted: felt) = MathUD58x18.div_fixed(
        jump_multiplier_per_second, kink_utilization_rate_
    );

    Jump_Multiplier_Per_Second.write(value=Uint256(jump_multiplier_per_second_adjusted, 0));

    //
    // EVENT: NewInterestRateModel
    //
    NewInterestRateModel.emit(
        base_rate_per_year, multiplier_per_year, kink_multiplier_, kink_utilization_rate_
    );

    return ();
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//      6. NON-CONSTANT FUNCTIONS
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────── External ───────────────────────────────────────────────────────

// @notice 👽
// @notice Sets a borrow tracker to reward borrowers in CYG or any other (if any).
// @custom:security non-reentrant
@external
func set_cygnus_borrow_rewarder{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_cygnus_borrow_rewarder: felt
) {
    // don't check for zero as child contract checks as whether it is 0 or not, to give rewards.

    // lock
    ReentrancyGuard._start();

    // assure caller is admin 👽
    cygnus_admin_internal();

    // read current borrow tracker
    let (old_cygnus_borrow_rewarder: felt) = Cygnus_Borrow_Rewarder.read();

    //
    // ERROR: tracker_already_set Avoid setting same tracker again
    //
    with_attr error_message("borrow_control__tracker_already_set({new_cygnus_borrow_rewarder})") {
        assert_not_equal(old_cygnus_borrow_rewarder, new_cygnus_borrow_rewarder);
    }

    // write new borrow tracker to storage
    Cygnus_Borrow_Rewarder.write(new_cygnus_borrow_rewarder);

    //
    // EVENT: NewCygnusBorrowRewarder
    //
    NewCygnusBorrowRewarder.emit(old_cygnus_borrow_rewarder, new_cygnus_borrow_rewarder);

    // unlock
    ReentrancyGuard._end();

    return ();
}

// @notice 👽
// @notice Sets a new reserve factor within min and max ranges allowed
// @custom:security non-reentrant
@external
func set_reserve_factor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_reserve_factor: Uint256
) {
    // lock
    ReentrancyGuard._start();

    // check is caller is admin 👽
    cygnus_admin_internal();

    // check if within valid range, reverts if not
    valid_range_internal(new_reserve_factor.low, 0, RESERVE_FACTOR_MAX);

    // get current reserve_factor
    let (old_reserve_factor: Uint256) = Reserve_Factor.read();

    // write new reserve factor to storage
    Reserve_Factor.write(new_reserve_factor);

    //
    // EVENT: NewReserveFactor
    //
    NewReserveFactor.emit(old_reserve_factor, new_reserve_factor);

    // unlock
    ReentrancyGuard._end();

    return ();
}

// @notice 👽
// @notice Sets a interest rate model for this pool
// @custom:security non-reentrant
@external
func set_interest_rate_model{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    base_rate_per_year: felt,
    multiplier_per_year: felt,
    kink_multiplier_: felt,
    kink_utilization_rate_: felt,
) {
    // lock
    ReentrancyGuard._start();

    // check is caller is admin 👽
    cygnus_admin_internal();

    // update internally and do sufficient checks
    interest_rate_model_internal(
        base_rate_per_year, multiplier_per_year, kink_multiplier_, kink_utilization_rate_
    );

    // unlock
    ReentrancyGuard._end();

    return ();
}
