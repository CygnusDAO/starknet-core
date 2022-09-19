%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address,
    get_block_timestamp,
)

// simple returns to use as expressions

// msg.sender
func msg_sender{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> felt {
    let (caller_address: felt) = get_caller_address();
    return caller_address;
}

// address(this)
func address_this{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> felt {
    let (contract_address: felt) = get_contract_address();
    return contract_address;
}

// block.timestamp
func block_timestamp{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> felt {
    let (block_timestamp_: felt) = get_block_timestamp();
    return block_timestamp_;
}
