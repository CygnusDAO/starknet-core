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
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin

// Starknet syscalls
from starkware.starknet.common.syscalls import deploy

// Utils
// simple returns for get_caller_address, get_contract_address and get_block_timestamp
from src.cygnus_core.utils.context import msg_sender

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     2. STRUCTS - INTERNAL
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// / @custom:struct CollateralParameters Important parameters for the collateral contracts
// / @custom:member factory The address of the Cygnus factory
// / @custom:member underlying The address of the underlying LP Token
// / @custom:member cygnusDai The address of the Cygnus borrow contract for this collateral
// / @custom:member shuttleId The unique id of this lending pool (shared by borrowable)
struct CollateralParameters {
    factory: felt,
    borrowable: felt,
    underlying: felt,
    shuttle_id: felt,
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     3. STORAGE - INTERNAL
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// / @notice Collateral class hash for this orbiter
const COLLATERAL_CLASS_HASH = 0x0049f7e95d735c1025e945fc02609a1e893de2146689a8e67d30be0ece8a6681;

// / @return CollateralParameters Single storage slot for the struct of the collateral params being passed
@storage_var
func Collateral_Parameters() -> (CollateralParameters: CollateralParameters) {
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     5. STORAGE ACCESSORS - EXTERNAL
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

//
// @notice Each collateral orbiter should have a unique class hash, or else there is no point in creating new orbiters
// @return COLLATERAL_CLASS_HASH The class hash of the collateral contract this orbiter deploys
//
@view
func collateral_class_hash() -> (COLLATERAL_CLASS_HASH: felt) {
    return (COLLATERAL_CLASS_HASH=COLLATERAL_CLASS_HASH);
}

// @notice This function gets called in the constructor when collaterals get deployed (see the
//         `cygnus_collateral_control` contract). When the factory calls this orbiter to deploy a collateral, the
//         address of factory, borrowable, underlying and the shuttle id get stored in this contract temporarily,
//         and gets overriden on every deployment. This is to avoid having constructor call data on deployments
// @return CollateralParameters A struct containing all the info of the collateral contract that this contract deploys
@view
func get_collateral_parameters{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) -> (CollateralParameters: CollateralParameters) {
    return Collateral_Parameters.read();
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     7. NON-CONSTANT FUNCTIONS - EXTERNAL
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// @notice Deploys collateral pools
// @param borrowable Address of this collateral`s borrowable
// @param underlying Address of this collateral`s underlying asset (an LP Token)
// @param shuttle_id Unique id of this lending pool shared by the borrowable
// @return collateral The address of the collateral contract deployed
@external
func deploy_collateral{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    borrowable: felt, underlying: felt, shuttle_id: felt
) -> (collateral: felt) {
    // ───────────────────────────────────────────────────

    // address of the msg.sender (ie cygnus factory address)
    let factory: felt = msg_sender();

    // build collateral params for this pool
    let params = CollateralParameters(
        factory=factory, borrowable=borrowable, underlying=underlying, shuttle_id=shuttle_id
    );

    // write params to storage to retrieve in constructors
    Collateral_Parameters.write(params);

    // ───────────────────────────────────────────────────

    // create salt of collateral address + factory address
    let (salt) = hash2{hash_ptr=pedersen_ptr}(underlying, msg_sender());

    // constructor calldata
    let constructor_calldata: felt* = alloc();

    // deploy collateral pool
    let (collateral: felt) = deploy(
        class_hash=COLLATERAL_CLASS_HASH,
        contract_address_salt=salt,
        constructor_calldata_size=0,
        constructor_calldata=constructor_calldata,
        deploy_from_zero=0,
    );

    return (collateral=collateral);
}
