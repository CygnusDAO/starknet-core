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
//     Collateral Orbiter In Cairo - `Deneb`
// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// SPDX-License-Identifier: Unlicensed
%lang starknet

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

// @title  DenebOrbiter Contract that deploys the Cygnus Collateral arm of the lending pool
// @author CygnusDAO
// @notice The Collateral Deployer contract which starts the collateral arm of the lending pool. It deploys
//         the collateral contract with the corresponding Cygnus borrowable contract address. We pass
//         structs to avoid having to set constructors in the core contracts, being able to calculate
//         addresses of lending pools with HASH2

// ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

@contract_interface
namespace IDenebOrbiter {
    // ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
    //     4. STORAGE ACCESSORS
    // ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

    //
    // @notice Each collateral orbiter should have a unique class hash, or else there is no point in creating new orbiters
    // @return COLLATERAL_CLASS_HASH The class hash of the collateral contract this contract deploys
    //
    func collateral_class_hash() -> (COLLATERAL_CLASS_HASH: felt) {
    }

    //
    // @notice This function gets called in the constructor when collaterals get deployed (see the
    //         `cygnus_collateral_control` contract). When the factory calls this contract to deploy a collateral, the
    //         address of factory, borrowable, underlying and the shuttle id get stored in this contract temporarily,
    //         and gets overriden on every deployment. This is to avoid having constructor call data on deployments
    // @return CollateralParameters A struct containing all the info of the collateral contract that this contract deploys
    //
    func get_collateral_parameters() -> (
        factory: felt, borrowable: felt, underlying: felt, shuttle_id: felt
    ) {
    }

    // ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
    //     7. NON-CONSTANT FUNCTIONS
    // ════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

    // @notice Deploys collateral pools
    // @param underlying The address of this collateral`s underlying asset (an LP Token representing user`s liquidity)
    // @param borrowable The address of this collateral`s borrowable
    // @param shuttle_id The unique id of this lending pool
    //
    func deploy_collateral(borrowable: felt, underlying: felt, shuttle_id: felt) -> (
        collateral: felt
    ) {
    }
}
