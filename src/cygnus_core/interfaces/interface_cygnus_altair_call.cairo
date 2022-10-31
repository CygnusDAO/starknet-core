%lang starknet

from starkware.cairo.common.uint256 import Uint256

// @custom:struct BorrowCallData Callback addresses for the leverage function.
//                  - See the borrow_function in the cygnus_borrow contract
//                cygnus_borrow contract)
// @custom:member calldata Ignores leverage if calldata is 0 (ie. to just borrow DAI we just set this to 0. To leverage we
//                must set this to 1 followed by the other struct members
// @custom:member lp_token_pair The address of the LP Token
// @custom:member collateral The address of the Cygnus collateral contract
// @custom:member borrow The address of the Cygnus borrow contract
// @custom:member recipient The address of the recipient
struct BorrowCallData {
    calldata: felt,
    lp_token_pair: felt,
    collateral: felt,
    borrowable: felt,
    recipient: felt,
}

// @custom:struct RedeemCallData Callbar addresses for the de-leverage function.
//                  - See the `flash_redeem_altair` function in the cygnus_collateral contract
// @custom:member collateral The address of the collateral contract
// @custom:member borrowable The address of the borrow contract
// @custom:member recipient The address of the user deleveraging LP Tokens
// @custom:member redeem_tokens The amount of CygLP to redeem
// @custom:member redeem_amount The amount of LP to redeem
struct RedeemCallData {
    calldata: felt,
    lp_token_pair: felt,
    collateral: felt,
    borrowable: felt,
    recipient: felt,
    redeem_tokens: Uint256,
    redeem_amount: Uint256,
}

@contract_interface
namespace ICygnusAltairCall {
    func altair_borrow(sender: felt, borrow_amount: Uint256, borrow_calldata: BorrowCallData) {
    }

    func altair_redeem(sender: felt, redeem_amount: Uint256, redeem_calldata: RedeemCallData) {
    }
}
