%lang starknet

from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from src.cygnus_core.interfaces.interface_erc20 import IERC20

// @title Safe ERC20
// @description A library for safe interactions with ERC20 contracts
// @author Peteris <github.com/Pet3ris>
namespace SafeERC20 {
    func transfer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        contract_address: felt, recipient: felt, amount: Uint256
    ) {
        let (success) = IERC20.transfer(
            contract_address=contract_address, recipient=recipient, amount=amount
        );

        with_attr error_message("SafeErc20__transfer_did_not_succeed({recipient})") {
            assert success = TRUE;
        }

        return ();
    }

    func transferFrom{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        contract_address: felt, sender: felt, recipient: felt, amount: Uint256
    ) {
        let (success) = IERC20.transferFrom(
            contract_address=contract_address, sender=sender, recipient=recipient, amount=amount
        );

        with_attr error_message("SafeErc20__transfer_from_did_not_succeed({recipient})") {
            assert success = TRUE;
        }

        return ();
    }

    func approve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(contract_address: felt, spender : felt, amount : Uint256){
      let (success) = IERC20.approve(contract_address=contract_address, spender=spender, amount=amount);
    
        with_attr error_message("SafeErc20__approve_did_not_succeed({spender}, {amount})") {
            assert success = TRUE;
        }

        return ();
    }
}
