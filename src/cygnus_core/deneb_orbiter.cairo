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
//         Collateral Orbiter In Cairo - `Deneb`
//
// @title  DenebOrbiter Contract that deploys the Cygnus Collateral arm of the lending pool
// @author CygnusDAO
// @notice The Collateral Deployer contract which starts the collateral arm of the lending pool. It deploys
//         the collateral contract with the corresponding Cygnus borrowable contract address. We pass
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
struct CollateralParameters {
    factory: felt,
    borrowable: felt,
    underlying: felt,
    shuttle_id: felt,
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     3. STORAGE - INTERNAL
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// @return CollateralParameters Single storage slot for the struct of the collateral params being passed
@storage_var
func Collateral_Parameters() -> (collateral_parameters: CollateralParameters) {
}

@storage_var
func Collateral_Class_Hash() -> (collateral_class_hash : felt){
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     4. CONSTRUCTOR
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(class_hash : felt) { 
  Collateral_Class_Hash.write(class_hash);
  return ();
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     5. STORAGE ACCESSORS - EXTERNAL
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// @notice Each collateral orbiter should have a unique class hash, or else there is no point in creating new orbiters
// @return COLLATERAL_CLASS_HASH The class hash of the collateral contract this contract deploys
@view
func collateral_class_hash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (collateral_class_hash: felt) {
    return Collateral_Class_Hash.read();
}

// @notice This function gets called in the constructor when collaterals get deployed (see the
//         `cygnus_collateral_control` contract). When the factory calls this contract to deploy a collateral, the
//         address of factory, borrowable, underlying and the shuttle id get stored in this contract temporarily,
//         and gets overriden on every deployment. This is to avoid having constructor call data on deployments
// @return CollateralParameters A struct containing all the info of the collateral contract that this contract deploys
@view
func get_collateral_parameters{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) -> (collateral_parameters: CollateralParameters) {
    return Collateral_Parameters.read();
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     7. NON-CONSTANT FUNCTIONS - EXTERNAL
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// @notice Deploys collateral pools
// @param borrowable Address of this collateral`s borrowable
// @param underlying Address of this collateral`s underlying asset (an LP Token representing user`s liquidity)
// @param shuttle_id Unique id of this lending pool shared by the borrowable
@external
func deploy_collateral{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    borrowable: felt, underlying: felt, shuttle_id: felt
) -> (collateral: felt) {
    //
    // 1. Address of the msg.sender (ie cygnus factory address)
    //
    let factory: felt = msg_sender();

    //
    // 2. Build collateral parameters passed from factory with borrowable address
    //
    let params = CollateralParameters(
        factory=factory, borrowable=borrowable, underlying=underlying, shuttle_id=shuttle_id
    );

    //
    // 3. Write params to storage to retrieve in constructors
    //
    Collateral_Parameters.write(params);

    // ───────────────────────────────────────────────────

    //
    // 4. Deploy collateral
    //

    // Create salt of LP Token address + factory address (msg_sender)
    let (salt) = hash2{hash_ptr=pedersen_ptr}(underlying, factory);

    // Constructor calldata (none)
    let constructor_calldata: felt* = alloc();

    let (collateral_class_hash : felt) = Collateral_Class_Hash.read();

    // Deploy collateral contract
    let (collateral: felt) = deploy(
        class_hash=collateral_class_hash,
        contract_address_salt=salt,
        constructor_calldata_size=0,
        constructor_calldata=constructor_calldata,
        deploy_from_zero=0,
    );

    return (collateral=collateral);
}
