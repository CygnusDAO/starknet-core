// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
// .               .            .               .      🛰️     .           .                .           .
//        █████████           ---======*.                                                 .           ⠀
//       ███░░░░░███                                               📡                🌔
//      ███     ░░░  █████ ████  ███████ ████████   █████ ████  █████        ⠀
//     ░███         ░░███ ░███  ███░░███░░███░░███ ░░███ ░███  ███░░      .     .⠀           .           .
//     ░███          ░███ ░███ ░███ ░███ ░███ ░███  ░███ ░███ ░░█████       ⠀
//     ░░███     ███ ░███ ░███ ░███ ░███ ░███ ░███  ░███ ░███  ░░░░███              .             .⠀
//      ░░█████████  ░░███████ ░░███████ ████ █████ ░░████████ ██████     .----===*  ⠀
//       ░░░░░░░░░    ░░░░░███  ░░░░░███░░░░ ░░░░░   ░░░░░░░░ ░░░░░░            .                            .
//                    ███ ░███  ███ ░███                .                 .                 .  ⠀
//  🛰️  .             ░░██████  ░░██████                                             .                 .
//                    ░░░░░░    ░░░░░░      -------=========*                      .                     ⠀
//        .                            .       .          .            .                          .
//
//         Borrow Orbiter In Cairo - `Albireo`
//
// @title  AlbireoOrbiter Contract that deploys the Cygnus Borrow arm of the lending pool
// @author CygnusDAO
// @notice The Borrow Deployer contract which starts the borrow arm of the lending pool. It deploys
//         the borrow contract with the corresponding Cygnus collateral contract address. We pass
//         structs to avoid having to set constructors in the core contracts, being able to calculate
//         addresses of lending pools with HASH2
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// SPDX-License-Identifier: Unlicensed
%lang starknet

// Cairo libraries
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math import assert_not_zero, assert_not_equal
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_check
from starkware.cairo.common.cairo_builtins import HashBuiltin

// Starknet syscalls
from starkware.starknet.common.syscalls import deploy

// Utils
from src.cygnus_core.utils.context import msg_sender, address_this

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     1. STRUCTS AND CONSTANTS - INTERNAL
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// @custom:struct CollateralParameters Important parameters for the collateral contracts
// @custom:member factory The address of the Cygnus factory
// @custom:member underlying The address of the underlying LP Token
// @custom:member cygnusDai The address of the Cygnus borrow contract for this collateral
// @custom:member shuttleId The unique id of this lending pool (shared by borrowable)
struct BorrowableParameters {
    factory: felt,
    collateral: felt,
    underlying: felt,
    shuttle_id: felt,
    base_rate_per_year: felt,
    multiplier_per_year: felt,
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     3. STORAGE - INTERNAL
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// @notice borrowable contract class hash
@storage_var
func Borrowable_Class_Hash() -> (borrowable_class_hash: felt) {
}

// @return CollateralParameters Single storage slot for the struct of the collateral params being passed
@storage_var
func Borrowable_Parameters() -> (borrowable_parameters: BorrowableParameters) {
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     4. CONSTRUCTOR
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// @notice constructrs the Borrow deployer
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(class_hash : felt) { 
  Borrowable_Class_Hash.write(class_hash);
  return ();
}


// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     5. STORAGE ACCESSORS - EXTERNAL
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// @notice Each collateral orbiter should have a unique class hash, or else there is no point in creating new orbiters
// @return BORROWABLE_CLASS_HASH The class hash of the collateral contract this contract deploys
@view
func borrowable_class_hash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    borrowable_class_hash: felt
) {
    return Borrowable_Class_Hash.read();
}

// @notice This function gets called in the constructor when borrowables get deployed (see the
//         `cygnus_borrow_control` contract). When the factory calls this contract to deploy a borrowable, the
//         address of factory, collateral, underlying and the shuttle id get stored in this contract temporarily,
//         and gets overriden on every deployment. This is to avoid having constructor call data on deployments
// @return BorrowableParameters A struct containing all the info of the borrowable contract that this contract deploys
@view
func get_borrowable_parameters{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) -> (borrowable_parameters: BorrowableParameters) {
    return Borrowable_Parameters.read();
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     7. NON-CONSTANT FUNCTIONS - EXTERNAL
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// @notice Deploys collateral pools
// @param collateral Address of this borrowable`s collateral
// @param underlying Address of this borrowable`s underlying asset (DAI)
// @param shuttle_id Unique id of this lending pool shared by the collateral
// @return borrowable The address of the borrowable contract deployed
@external
func deploy_borrowable{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    collateral: felt,
    underlying: felt,
    shuttle_id: felt,
    base_rate_per_year: felt,
    multiplier_per_year: felt,
) -> (borrowable: felt) {
    //
    // 1. Address of the msg.sender (ie cygnus factory address)
    //
    let factory: felt = msg_sender();

    //
    // 2. Build borrowable parameters passed from factory with collateral address
    //
    let params = BorrowableParameters(
        factory=factory,
        collateral=collateral,
        underlying=underlying,
        shuttle_id=shuttle_id,
        base_rate_per_year=base_rate_per_year,
        multiplier_per_year=multiplier_per_year,
    );

    //
    // 3. Write params to storage to retrieve in constructors
    //
    Borrowable_Parameters.write(params);

    // ───────────────────────────────────────────────────

    //
    // 4. Deploy collateral
    //

    // Create salt of Collateral address + factory address (msg_sender)
    let (salt) = hash2{hash_ptr=pedersen_ptr}(collateral, factory);

    // Get class Hash
    let (borrowable_class_hash: felt) = Borrowable_Class_Hash.read();

    // Constructor calldata (none)
    let constructor_calldata: felt* = alloc();

    // Deploy borrowable contract
    let (borrowable: felt) = deploy(
        class_hash=borrowable_class_hash,
        contract_address_salt=salt,
        constructor_calldata_size=0,
        constructor_calldata=constructor_calldata,
        deploy_from_zero=0,
    );

    return (borrowable=borrowable);
}
