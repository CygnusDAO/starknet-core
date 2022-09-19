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
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin

// Starknet syscalls
from starkware.starknet.common.syscalls import deploy

// Utils
from src.cygnus_core.utils.context import msg_sender

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     2. STRUCTS - INTERNAL
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
const BORROWABLE_CLASS_HASH = 0x0078e0b28be067200188de1424c4479430433a824252c72fadf9e81dd066e3b6;

// @return CollateralParameters Single storage slot for the struct of the collateral params being passed
@storage_var
func Borrowable_Parameters() -> (BorrowableParameters: BorrowableParameters) {
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     5. STORAGE ACCESSORS - EXTERNAL
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// @notice Each borrowable orbiter should have a unique class hash, or else there is no point in creating new orbiters
// @return BORROWABLE_CLASS_HASH The class hash of the borrowable contract this orbiter deploys
@view
func borrowable_class_hash() -> (BORROWABLE_CLASS_HASH: felt) {
    return (BORROWABLE_CLASS_HASH=BORROWABLE_CLASS_HASH);
}

// @notice This function gets called in the constructor when borrowables get deployed (see the
//         `cygnus_borrow_control` contract). When the factory calls this orbiter to deploy a borrowable, the
//         address of factory, collateral, underlying and the shuttle id get stored in this contract temporarily,
//         and gets overriden on every deployment. This is to avoid having constructor call data on deployments
// @return BorrowableParameters A struct containing all the info of the borrowable contract that this contract deploys
@view
func get_borrowable_parameters{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) -> (BorrowableParameters: BorrowableParameters) {
    return Borrowable_Parameters.read();
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
//     7. NON-CONSTANT FUNCTIONS - EXTERNAL
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// @notice Deploys borrowable pools
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
    // ───────────────────────────────────────────────────

    // address of the msg.sender (ie cygnus factory address)
    let factory: felt = msg_sender();

    // build collateral params for this pool
    let params = BorrowableParameters(
        factory=factory,
        collateral=collateral,
        underlying=underlying,
        shuttle_id=shuttle_id,
        base_rate_per_year=base_rate_per_year,
        multiplier_per_year=multiplier_per_year
    );

    // write params to storage to retrieve in constructors
    Borrowable_Parameters.write(params);

    // ───────────────────────────────────────────────────

    // create salt of collateral address + factory address
    let (salt) = hash2{hash_ptr=pedersen_ptr}(collateral, msg_sender());

    // constructor calldata
    let constructor_calldata: felt* = alloc();

    // deploy lending pool
    let (borrowable: felt) = deploy(
        class_hash=BORROWABLE_CLASS_HASH,
        contract_address_salt=salt,
        constructor_calldata_size=0,
        constructor_calldata=constructor_calldata,
        deploy_from_zero=0,
    );

    return (borrowable=borrowable);
}
