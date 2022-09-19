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
//     Borrowable Orbiter In Cairo V1 - `Albireo`
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// SPDX-License-Identifier: Unlicensed
%lang starknet

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// @title  AlbireoOrbiter Contract that deploys the Cygnus Borrow arm of the lending pool
// @author CygnusDAO
// @notice The borrowable deployer contract which starts the borrowable arm of the lending pool. It deploys
//         the borrowable contract with the corresponding Cygnus collateral contract address. We pass
//         structs to avoid having to set constructors in the core contracts, being able to calculate
//         addresses of lending pools with HASH2

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

@contract_interface
namespace IAlbireoOrbiter {
    // ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
    //     4. STORAGE ACCESSORS
    // ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

    //
    // @notice Each borrowable orbiter should have a unique class hash, or else there is no point in creating new orbiters
    // @return BORROWABLE_CLASS_HASH The class hash of the borrowable contract this contract deploys
    //
    func borrowable_class_hash() -> (BORROWABLE_CLASS_HASH: felt) {
    }

    //
    // @notice get borrowable params struct
    //
    func get_borrowable_parameters() -> (
        factory: felt,
        collateral: felt,
        underlying: felt,
        shuttle_id: felt,
        base_rate_per_year: felt,
        multiplier_per_year: felt,
    ) {
    }

    // ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
    //     7. NON-CONSTANT FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

    // @notice Deploys collateral pools
    //
    func deploy_borrowable(
        collateral: felt, underlying: felt, shuttle_id: felt, base_rate_per_year: felt, multiplier_per_year: felt
    ) -> (borrowable: felt) {
    }
}
