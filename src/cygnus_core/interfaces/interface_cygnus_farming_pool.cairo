// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.3.1 (token/erc20/IERC20.cairo)
%lang starknet

from starkware.cairo.common.uint256 import Uint256, uint256_check, uint256_le, uint256_lt

@contract_interface
namespace ICygnusFarmingPool {
    func track_borrow(borrower: felt, account_borrows: Uint256, borrow_index_stored: Uint256) {
    }
}
