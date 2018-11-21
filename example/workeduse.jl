
using Base: IEEEFloat, unsigned, sign_mask, exponent_mask, significand_mask

using BitsFields

Base.unsigned(::Type{Float64}) = UInt64
Base.unsigned(::Type{Float32}) = UInt32
Base.unsigned(::Type{Float16}) = UInt16


mutable struct FP{T,U}
    floating::T
    unsigned::U
end

value(x::FP{T,U}) where {T,U} = x.floating

FP(x::T) where {T<:IEEEFloat} = FP{T,unsigned(T)}(x, reinterpret(unsigned(T), x))
FP(x::U) where {U<:Unsigned}  = FP{float(U),U}(reinterpret(float(T), x), x)

Base.show(io::IO, x::FP{T,U}) where {T,U} = show(io, value(x))

Base.:(+)(x::T, fp::FP{T,U}) where {T,U} = x + value(fp)
Base.:(+)(x::FP{T,U}, y::FP{T,U}) where {T,U} = FP(value(x) + value(y))




"""
    fieldspan

How many bits does this field span?

The tally of 1-bits in the field's mask gives its span.
All bits of a bitfield are adjacent to at least one other
bit within the bitfield. Interior bits, if any (if the
bitfield has a span of three or more), are adjacent to
two bits within bitfield.

To tally the 1-bits, we subtract any leading 0-bits
and subtract any trailing 0-bits from the
number of bits provided and given by the value_store.
(This way, no reliance on tabulated values is needed.
 We stay within the information availablilty of Julia.)
""" 
fieldspan(::Type{T}, fieldmask) where {T<:IEEEFloat} =
   bitsof(T) - leading_zeros(fieldmask(T)) - trailing_zeros(fieldmask(T))

"""
    fieldshift

By how many bits is this field shifted?
   - how far is the least significant bit of the field
     from the least significant bit of all the fields

To determine the number of bits over which a bitfield
is shifted (from low-order bits to high-order bits),
we count the empty bit positions that trail the bitfield.
"""
fieldshift(::Type{T}, fieldmask) where {T<:IEEEFloat} =
   trailing_zeros(fieldmask(T))


UI = UInt64
FP = float(UI) # Float64

for N in (64, 32, 16)
    for (Field, Name, Mask) in ( (:signfield, :sign, :sign_mask), 
                                 (:exponentfield, :exponent, :exponent_mask), 
                                 (:significandfield, :significand, :significand_mask) )
        @eval begin
            $Field$N = BitField(UInt$N, fieldspan(Float$N, $Mask), fieldshift(Float$N, $Mask), Symbol($Name))
        end
    end
end

float64bits = BitFields(signfield, exponentfield, significandfield)

float64 = NamedTuple(float64bits);

function mulbytwo(x::FP{T,U}) where {T<:IEEEFloat}
    originalexponent = get(exponent(T), UNSIGNED(x))
    # check for potential overflow
    if originalexponent === exponentfield.ones
        throw(OverflowError("$(x.fp) * 2"))
    end
    
    mulbytwoexponent = originalexponent + one(U)
    set!(exponent(T), mulbytwoexponent, x.unsigned)
    x.floating = reinterpret(T, x.unsigned)
    
    return x
end





fpvalue = Ref(reinterpret(UInt64, inv(sqrt(Float64(2.0)))))

set!(float64.exponent,
     get(float64.exponent,fpvalue) + 1,
     fpvalue)

reinterpret(Float64,fpvalue[])
1.414213562373095

