%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace ICygnusTerminal {
    //
    // TERMINAL
    //
    func total_balance() -> (total_balance: Uint256) {
    }

    func underlying() -> (underlying: felt) {
    }

    func giza_power_plant() -> (giza_power_plant: felt) {
    }

    func shuttle_id() -> (shuttle_id: felt) {
    }

    func exchange_rate() -> (exchange_rate: Uint256) {
    }

    func deposit(assets: Uint256, recipient: felt) -> (shares: Uint256) {
    }

    func redeem(shares: Uint256, recipient: felt, owner: felt) -> (assets: Uint256) {
    }

    //
    // ERC2O
    //
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
