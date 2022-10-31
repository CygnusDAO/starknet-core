%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IERC20 {
    func name() -> (name: felt) {
    }

    func symbol() -> (symbol: felt) {
    }

    func decimals() -> (decimals: felt) {
    }

    func totalSupply() -> (total_supply: Uint256) {
    }

    func balanceOf(account: felt) -> (balance: Uint256) {
    }

    func allowance(owner: felt, spender: felt) -> (allowance: Uint256) {
    }

    func approve(spender: felt, amount: Uint256) -> (bool: felt) {
    }

    func decreaseAllowance(spender: felt, subtracted_value: Uint256) -> (bool: felt) {
    }

    func transfer(recipient: felt, amount: Uint256) -> (bool: felt) {
    }

    func transferFrom(sender: felt, recipient: felt, amount: Uint256) -> (bool: felt) {
    }

    func increaseAllowance(spender: felt, added_value: Uint256) -> (bool: felt) {
    }
}
