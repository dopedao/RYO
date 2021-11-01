%lang starknet

from starkware.cairo.common.cairo_builtins import (HashBuiltin,
    BitwiseBuiltin)
from starkware.cairo.common.hash_state import (hash_init,
    hash_update, HashState)
from starkware.cairo.common.math import unsigned_div_rem

# Computes the unique hash of a list of felts.
func list_to_hash{
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        list : felt*,
        list_len : felt
    ) -> (
        hash : felt
    ):
    let (list_hash : HashState*) = hash_init()
    let (list_hash : HashState*) = hash_update{
        hash_ptr=pedersen_ptr}(list_hash, list, list_len)
    return (list_hash.current_hash)
end


# Generic mapping from one range to another.
func scale{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*
    } (
        val_in : felt,
        in_low : felt,
        in_high : felt,
        out_low : felt,
        out_high : felt
    ) -> (
        val_out : felt
    ):
    # val_out = ((val_in - in_low) / (in_high - in_low))
    #           * (out_high - out_low) + out_low
    let a = (val_in - in_low) * (out_high - out_low)
    let b = in_high - in_low
    let (c, _) = unsigned_div_rem(a, b)
    let val_out = c + out_low
    return (val_out)
end
