module THActions

export SB_ID
export BB_ID
export CALL_ID
export CHECK_ID
export FOLD_ID
export BET_ID
export ALL_ID
export RAISE_ID
export CHANCE_ID

export CALL
export FOLD
export CHECK
export CHANCE
export ALL

export AFTER_CALL
export AFTER_RAISE
export AFTER_CHECK
export AFTER_BET
export AFTER_FOLD
export AFTER_CHANCE
export AFTER_BB
export AFTER_ALL
export AFTER_SB
export ACTION_SET1
export ACTION_SET2
export ACTION_SET3

using actions

using StaticArrays

const NULL_ID = UInt8(0)
const CALL_ID = UInt8(1)
const FOLD_ID = UInt8(2)
const CHECK_ID = UInt8(3)
const RAISE_ID =  UInt8(4)
const BET_ID =  UInt8(5)
const SB_ID =  UInt8(6)
const BB_ID =  UInt8(7)
const CHANCE_ID =  UInt8(8)
const ALL_ID =  UInt8(9)

const ACTION_SET1 = @SVector [CALL_ID, FOLD_ID, RAISE_ID, ALL_ID]
const ACTION_SET2 = @SVector [FOLD_ID, CHECK_ID, BET_ID, ALL_ID]
const ACTION_SET3 = @SVector [CHECK_ID, RAISE_ID, ALL_ID]

const AFTER_CALL = @SVector [CALL_ID, FOLD_ID, CHECK_ID, RAISE_ID, ALL_ID]

const AFTER_RAISE = ACTION_SET1
const AFTER_BET = ACTION_SET1
const AFTER_BB = ACTION_SET1

const AFTER_CHECK = ACTION_SET2
const AFTER_CHANCE = ACTION_SET2

const AFTER_FOLD = AFTER_CALL

const AFTER_ALL = @SVector [CALL_ID, FOLD_ID, CHECK_ID, ALL_ID]
const AFTER_SB = @SVector [BB_ID]

struct THAction{T<:AbstractFloat} <: Action
    id::UInt8
    pot_multiplier::T
    blind_multiplier::T
end

const CALL = THAction(CALL_ID, 0, 0)
const FOLD = THAction(FOLD_ID, 0, 0)
const CHECK = THAction(CHECK_ID, 0, 0)
const ALL = THAction(ALL_ID, 0, 0)
const CHANCE = THAction(CHANCE_ID, 0, 0)

# ActionSet(acts::Vector{Action}) = ActionSet(acts::Vector{Action}, false)

Base.hash(a::Action, h::UInt) = hash(a.id, hash(a.pot_multiplier, hash(a.blind_multiplier, hash(:Action, h))))

@inline function Base.:(==)(p1::Action, p2::Action)
    return p1.id == p2.id && p1.pot_multiplier == p2.pot_multiplier && p1.blind_multiplier == p2.blind_multiplier
end

@inline function Base.isless(p1::Action, p2::Action)
    if p1.id == p2.id
        return p1.pot_multiplier <= p2.pot_multiplier && p1.blind_multiplier <= p2.blind_multiplier
    end
    return p1.id < p2.id
end

@inline function Base.:(<)(p1::Action, p2::Action)
    return isless(p1, p2)
end

@inline function legalactions!(mask::MVector{A, Bool}, n_actions::T) where {A, T <: Integer}
    # sorts actions such that the active ones are at the top 

    idx = StaticArrays.sacollect(MVector{A, T}, 1:A)
    
    #todo we might not need to copy the mask, since it gets overwritten anyway
    
    mask = copy(mask)
    i = 1

    while i < n_actions + 1
        if mask[i] == 0
            j = i + 1
            
            while j < A + 1
                if mask[j] == 1
                    #permute index
                    k = idx[i]
                    idx[i] = idx[j]
                    idx[j] = k
                    mask[i] = 1
                    mask[j] = 0
                    break
                end

                j += 1

            end
        end

        i += 1
    end

    return idx

end

@inline function Base.sort!(s::ActionSet)
    if s.sorted != true
        sort!(s.actions)
        s.sorted = false
    end
end


end
