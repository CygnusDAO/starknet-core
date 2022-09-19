// SPDX-License-Identifier: Unlicensed
%lang starknet

from starkware.cairo.common.hash_state import (
    hash_finalize,
    hash_init,
    hash_update,
    hash_update_single,
    hash_update_with_hashchain,
)
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.storage import normalize_address

// @notice https://github.com/starkware-libs/cairo-lang/blob/master/src/starkware/cairo/common/hash_state.cairo
//
// Calculates a new contract address before deploying given:
//   - Salt
//   - Class hash
//   - Constructor call data size
//   - Constructor call data
//   - Deployer address (this contract)
namespace CygnusAddressLib {
    //
    // @notice Contract address prefix used for all contract addresses on Starknet
    //
    const CONTRACT_ADDRESS_PREFIX = 'STARKNET_CONTRACT_ADDRESS';

    // @notice Calculates a future contract address on Starknet before deploying it
    // @param salt The salt for the fields that is being proved
    // @param class_hash The class hash of the contract we are deploying
    // @param constructor_calldata_size Size of the constructor params
    // @param constructor_calldata The constructor params
    // @param deployer_address The address of the deployer contract
    // @return contract_address The address of the contract
    func calculate_contract_address{hash_ptr: HashBuiltin*, range_check_ptr}(
        salt: felt,
        class_hash: felt,
        constructor_calldata_size: felt,
        constructor_calldata: felt*,
        deployer_address: felt,
    ) -> (contract_address: felt) {
        //
        // 1. Initialize a new HashState with no items
        //
        let (hash_state_ptr) = hash_init();

        //
        // 2. Hash with the starknet contract address prefix, ie. 'STARKNET_CONTRACT_ADDRESS'
        //
        let (hash_state_ptr) = hash_update_single(
            hash_state_ptr=hash_state_ptr, item=CONTRACT_ADDRESS_PREFIX
        );

        //
        // 3. Hash deployer address (the contract deploying it)
        //
        let (hash_state_ptr) = hash_update_single(
            hash_state_ptr=hash_state_ptr, item=deployer_address
        );

        //
        // 4. Hash salt
        //
        let (hash_state_ptr) = hash_update_single(hash_state_ptr=hash_state_ptr, item=salt);

        //
        // 5. Hash the class hash of the contract we are deploying
        //
        let (hash_state_ptr) = hash_update_single(hash_state_ptr=hash_state_ptr, item=class_hash);

        // 6. Compute the hash of the following and then call hash_update_single to add to the hash_state
        //   - hash_state_ptr
        //   - calldata
        //   - calldata size
        let (hash_state_ptr) = hash_update_with_hashchain(
            hash_state_ptr=hash_state_ptr,
            data_ptr=constructor_calldata,
            data_length=constructor_calldata_size,
        );

        // 7. Returns the final hash result of the HashState
        let (contract_address_before_modulo) = hash_finalize(hash_state_ptr=hash_state_ptr);

        // 8. Normalize address (addr % ADDR_BOUND) so for a valid storage item address in the storage tree
        // https://github.com/starkware-libs/cairo-lang/blob/master/src/starkware/starknet/common/storage.cairo
        //
        let (contract_address) = normalize_address(addr=contract_address_before_modulo);

        // return contract address
        return (contract_address=contract_address);
    }
}
